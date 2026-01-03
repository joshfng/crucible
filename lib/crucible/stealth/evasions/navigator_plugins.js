/**
 * Evasion: navigator.plugins
 * In headless mode navigator.mimeTypes and navigator.plugins are empty.
 * This plugin emulates both with functional mocks to match regular headful Chrome.
 */
(function() {
  'use strict';

  const utils = window._stealthUtils;
  if (!utils) return;

  // That means we're running headful
  const hasPlugins = 'plugins' in navigator && navigator.plugins.length;
  if (hasPlugins) {
    return; // Nothing to do here
  }

  // Plugin and MimeType data (matches Chrome)
  const mimeTypesData = [
    {
      type: 'application/pdf',
      suffixes: 'pdf',
      description: '',
      __pluginName: 'Chrome PDF Viewer'
    },
    {
      type: 'application/x-google-chrome-pdf',
      suffixes: 'pdf',
      description: 'Portable Document Format',
      __pluginName: 'Chrome PDF Plugin'
    },
    {
      type: 'application/x-nacl',
      suffixes: '',
      description: 'Native Client Executable',
      __pluginName: 'Native Client'
    },
    {
      type: 'application/x-pnacl',
      suffixes: '',
      description: 'Portable Native Client Executable',
      __pluginName: 'Native Client'
    }
  ];

  const pluginsData = [
    {
      name: 'Chrome PDF Plugin',
      filename: 'internal-pdf-viewer',
      description: 'Portable Document Format',
      __mimeTypes: ['application/x-google-chrome-pdf']
    },
    {
      name: 'Chrome PDF Viewer',
      filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai',
      description: '',
      __mimeTypes: ['application/pdf']
    },
    {
      name: 'Native Client',
      filename: 'internal-nacl-plugin',
      description: '',
      __mimeTypes: ['application/x-nacl', 'application/x-pnacl']
    }
  ];

  // Helper to define properties with vanilla descriptors
  const defineProp = (obj, prop, value) =>
    Object.defineProperty(obj, prop, {
      value,
      writable: false,
      enumerable: false,
      configurable: true
    });

  // Generate function mocks for item/namedItem/refresh
  const generateFunctionMocks = (proto, itemMainProp, dataArray) => ({
    item: utils.createProxy(proto.item, {
      apply(target, ctx, args) {
        if (!args.length) {
          throw new TypeError(
            `Failed to execute 'item' on '${proto[Symbol.toStringTag]}': 1 argument required, but only 0 present.`
          );
        }
        const isInteger = args[0] && Number.isInteger(Number(args[0]));
        return (isInteger ? dataArray[Number(args[0])] : dataArray[0]) || null;
      }
    }),
    namedItem: utils.createProxy(proto.namedItem, {
      apply(target, ctx, args) {
        if (!args.length) {
          throw new TypeError(
            `Failed to execute 'namedItem' on '${proto[Symbol.toStringTag]}': 1 argument required, but only 0 present.`
          );
        }
        return dataArray.find(mt => mt[itemMainProp] === args[0]) || null;
      }
    }),
    refresh: proto.refresh
      ? utils.createProxy(proto.refresh, {
          apply(target, ctx, args) {
            return undefined;
          }
        })
      : undefined
  });

  // Generate a magic array (MimeTypeArray or PluginArray)
  const generateMagicArray = (
    dataArray,
    proto,
    itemProto,
    itemMainProp
  ) => {
    const makeItem = data => {
      const item = {};
      for (const prop of Object.keys(data)) {
        if (prop.startsWith('__')) {
          continue;
        }
        defineProp(item, prop, data[prop]);
      }
      return patchItem(item, data);
    };

    const patchItem = (item, data) => {
      let descriptor = Object.getOwnPropertyDescriptors(item);

      // Plugins have a magic length property
      if (itemProto === Plugin.prototype) {
        descriptor = {
          ...descriptor,
          length: {
            value: data.__mimeTypes.length,
            writable: false,
            enumerable: false,
            configurable: true
          }
        };
      }

      const obj = Object.create(itemProto, descriptor);
      const blacklist = [...Object.keys(data), 'length', 'enabledPlugin'];

      return new Proxy(obj, {
        ownKeys(target) {
          return Reflect.ownKeys(target).filter(k => !blacklist.includes(k));
        },
        getOwnPropertyDescriptor(target, prop) {
          if (blacklist.includes(prop)) {
            return undefined;
          }
          return Reflect.getOwnPropertyDescriptor(target, prop);
        }
      });
    };

    const magicArray = [];

    dataArray.forEach(data => {
      magicArray.push(makeItem(data));
    });

    // Add direct property access based on types
    magicArray.forEach(entry => {
      defineProp(magicArray, entry[itemMainProp], entry);
    });

    const magicArrayObj = Object.create(proto, {
      ...Object.getOwnPropertyDescriptors(magicArray),
      length: {
        value: magicArray.length,
        writable: false,
        enumerable: false,
        configurable: true
      }
    });

    const functionMocks = generateFunctionMocks(proto, itemMainProp, magicArray);

    const magicArrayObjProxy = new Proxy(magicArrayObj, {
      get(target, key = '') {
        if (key === 'item') {
          return functionMocks.item;
        }
        if (key === 'namedItem') {
          return functionMocks.namedItem;
        }
        if (proto === PluginArray.prototype && key === 'refresh') {
          return functionMocks.refresh;
        }
        return utils.cache.Reflect.get(...arguments);
      },
      ownKeys(target) {
        const keys = [];
        const typeProps = magicArray.map(mt => mt[itemMainProp]);
        typeProps.forEach((_, i) => keys.push(`${i}`));
        typeProps.forEach(propName => keys.push(propName));
        return keys;
      },
      getOwnPropertyDescriptor(target, prop) {
        if (prop === 'length') {
          return undefined;
        }
        return Reflect.getOwnPropertyDescriptor(target, prop);
      }
    });

    return magicArrayObjProxy;
  };

  // Generate MimeTypeArray
  const mimeTypes = generateMagicArray(
    mimeTypesData,
    MimeTypeArray.prototype,
    MimeType.prototype,
    'type'
  );

  // Generate PluginArray
  const plugins = generateMagicArray(
    pluginsData,
    PluginArray.prototype,
    Plugin.prototype,
    'name'
  );

  // Cross-reference plugins and mimeTypes
  for (const pluginData of pluginsData) {
    pluginData.__mimeTypes.forEach((type, index) => {
      plugins[pluginData.name][index] = mimeTypes[type];

      Object.defineProperty(plugins[pluginData.name], type, {
        value: mimeTypes[type],
        writable: false,
        enumerable: false,
        configurable: true
      });
      Object.defineProperty(mimeTypes[type], 'enabledPlugin', {
        value:
          type === 'application/x-pnacl'
            ? mimeTypes['application/x-nacl'].enabledPlugin
            : new Proxy(plugins[pluginData.name], {}),
        writable: false,
        enumerable: false,
        configurable: true
      });
    });
  }

  // Patch navigator
  const patchNavigator = (name, value) =>
    utils.replaceProperty(Object.getPrototypeOf(navigator), name, {
      get() {
        return value;
      }
    });

  patchNavigator('mimeTypes', mimeTypes);
  patchNavigator('plugins', plugins);
})();
