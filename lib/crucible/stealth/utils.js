/**
 * Stealth utilities for modifying native browser APIs without leaving traces.
 * Ported from puppeteer-extra-plugin-stealth.
 */
(function() {
  'use strict';

  if (window._stealthUtils) return;

  const utils = {};

  utils.init = () => {
    utils.preloadCache();
  };

  /**
   * Preload a cache of function copies and data.
   */
  utils.preloadCache = () => {
    if (utils.cache) return;
    utils.cache = {
      Reflect: {
        get: Reflect.get.bind(Reflect),
        apply: Reflect.apply.bind(Reflect)
      },
      nativeToStringStr: Function.toString + ''
    };
  };

  /**
   * Generate a native toString result.
   */
  utils.makeNativeString = (name = '') => {
    return utils.cache.nativeToStringStr.replace('toString', name || '');
  };

  /**
   * Wrap a JS Proxy Handler and strip its presence from error stacks.
   */
  utils.stripProxyFromErrors = (handler = {}) => {
    const newHandler = {
      setPrototypeOf: function(target, proto) {
        if (proto === null)
          throw new TypeError('Cannot convert object to primitive value');
        if (Object.getPrototypeOf(target) === Object.getPrototypeOf(proto)) {
          throw new TypeError('Cyclic __proto__ value');
        }
        return Reflect.setPrototypeOf(target, proto);
      }
    };

    const traps = Object.getOwnPropertyNames(handler);
    traps.forEach(trap => {
      newHandler[trap] = function() {
        try {
          return handler[trap].apply(this, arguments || []);
        } catch (err) {
          if (!err || !err.stack || !err.stack.includes('at ')) {
            throw err;
          }

          const stripWithBlacklist = (stack, stripFirstLine = true) => {
            const blacklist = [
              `at Reflect.${trap} `,
              `at Object.${trap} `,
              `at Object.newHandler.<computed> [as ${trap}] `
            ];
            return err.stack
              .split('\n')
              .filter((line, index) => !(index === 1 && stripFirstLine))
              .filter(line => !blacklist.some(bl => line.trim().startsWith(bl)))
              .join('\n');
          };

          const stripWithAnchor = (stack, anchor) => {
            const stackArr = stack.split('\n');
            anchor = anchor || `at Object.newHandler.<computed> [as ${trap}] `;
            const anchorIndex = stackArr.findIndex(line =>
              line.trim().startsWith(anchor)
            );
            if (anchorIndex === -1) return false;
            stackArr.splice(1, anchorIndex);
            return stackArr.join('\n');
          };

          err.stack = err.stack.replace(
            'at Object.toString (',
            'at Function.toString ('
          );
          if ((err.stack || '').includes('at Function.toString (')) {
            err.stack = stripWithBlacklist(err.stack, false);
            throw err;
          }

          err.stack = stripWithAnchor(err.stack) || stripWithBlacklist(err.stack);
          throw err;
        }
      };
    });
    return newHandler;
  };

  /**
   * Replace the property of an object.
   */
  utils.replaceProperty = (obj, propName, descriptorOverrides = {}) => {
    return Object.defineProperty(obj, propName, {
      ...(Object.getOwnPropertyDescriptor(obj, propName) || {}),
      ...descriptorOverrides
    });
  };

  /**
   * Patch toString of an object.
   */
  utils.patchToString = (obj, str = '') => {
    const handler = {
      apply: function(target, ctx) {
        if (ctx === Function.prototype.toString) {
          return utils.makeNativeString('toString');
        }
        if (ctx === obj) {
          return str || utils.makeNativeString(obj.name);
        }
        const hasSameProto = Object.getPrototypeOf(
          Function.prototype.toString
        ).isPrototypeOf(ctx.toString);
        if (!hasSameProto) {
          return ctx.toString();
        }
        return target.call(ctx);
      }
    };

    const toStringProxy = new Proxy(
      Function.prototype.toString,
      utils.stripProxyFromErrors(handler)
    );
    utils.replaceProperty(Function.prototype, 'toString', {
      value: toStringProxy
    });
  };

  /**
   * Redirect toString from proxyObj to originalObj.
   */
  utils.redirectToString = (proxyObj, originalObj) => {
    const handler = {
      apply: function(target, ctx) {
        if (ctx === Function.prototype.toString) {
          return utils.makeNativeString('toString');
        }
        if (ctx === proxyObj) {
          const fallback = () =>
            originalObj && originalObj.name
              ? utils.makeNativeString(originalObj.name)
              : utils.makeNativeString(proxyObj.name);
          return originalObj + '' || fallback();
        }
        if (typeof ctx === 'undefined' || ctx === null) {
          return target.call(ctx);
        }
        const hasSameProto = Object.getPrototypeOf(
          Function.prototype.toString
        ).isPrototypeOf(ctx.toString);
        if (!hasSameProto) {
          return ctx.toString();
        }
        return target.call(ctx);
      }
    };

    const toStringProxy = new Proxy(
      Function.prototype.toString,
      utils.stripProxyFromErrors(handler)
    );
    utils.replaceProperty(Function.prototype, 'toString', {
      value: toStringProxy
    });
  };

  /**
   * Replace a property with a JS Proxy.
   */
  utils.replaceWithProxy = (obj, propName, handler) => {
    const originalObj = obj[propName];
    const proxyObj = new Proxy(obj[propName], utils.stripProxyFromErrors(handler));
    utils.replaceProperty(obj, propName, { value: proxyObj });
    utils.redirectToString(proxyObj, originalObj);
    return true;
  };

  /**
   * Replace a getter with a JS Proxy.
   */
  utils.replaceGetterWithProxy = (obj, propName, handler) => {
    const fn = Object.getOwnPropertyDescriptor(obj, propName).get;
    const fnStr = fn.toString();
    const proxyObj = new Proxy(fn, utils.stripProxyFromErrors(handler));
    utils.replaceProperty(obj, propName, { get: proxyObj });
    utils.patchToString(proxyObj, fnStr);
    return true;
  };

  /**
   * Mock a non-existing property with a JS Proxy.
   */
  utils.mockWithProxy = (obj, propName, pseudoTarget, handler) => {
    const proxyObj = new Proxy(pseudoTarget, utils.stripProxyFromErrors(handler));
    utils.replaceProperty(obj, propName, { value: proxyObj });
    utils.patchToString(proxyObj);
    return true;
  };

  /**
   * Create a new JS Proxy with stealth tweaks.
   */
  utils.createProxy = (pseudoTarget, handler) => {
    const proxyObj = new Proxy(pseudoTarget, utils.stripProxyFromErrors(handler));
    utils.patchToString(proxyObj);
    return proxyObj;
  };

  /**
   * Make all nested functions of an object native.
   */
  utils.patchToStringNested = (obj = {}) => {
    return utils.execRecursively(obj, ['function'], utils.patchToString);
  };

  /**
   * Traverse nested properties recursively.
   */
  utils.execRecursively = (obj = {}, typeFilter = [], fn) => {
    function recurse(obj) {
      for (const key in obj) {
        if (obj[key] === undefined) continue;
        if (obj[key] && typeof obj[key] === 'object') {
          recurse(obj[key]);
        } else {
          if (obj[key] && typeFilter.includes(typeof obj[key])) {
            fn.call(this, obj[key]);
          }
        }
      }
    }
    recurse(obj);
    return obj;
  };

  /**
   * Handler templates for re-usability.
   */
  utils.makeHandler = () => ({
    getterValue: value => ({
      apply(target, ctx, args) {
        utils.cache.Reflect.apply(...arguments);
        return value;
      }
    })
  });

  // Initialize and expose
  utils.init();
  window._stealthUtils = utils;
})();
