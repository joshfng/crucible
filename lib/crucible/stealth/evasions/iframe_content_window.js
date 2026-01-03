/**
 * Evasion: iframe.contentWindow
 * Fix for the HEADCHR_IFRAME detection (iframe.contentWindow.chrome).
 * Only srcdoc powered iframes cause issues due to a chromium bug.
 */
(function() {
  'use strict';

  const utils = window._stealthUtils;
  if (!utils) return;

  try {
    // Adds a contentWindow proxy to the provided iframe element
    const addContentWindowProxy = iframe => {
      const contentWindowProxy = {
        get(target, key) {
          // Make this thing behave like a regular iframe window
          if (key === 'self') {
            return this;
          }
          if (key === 'frameElement') {
            return iframe;
          }
          // Intercept iframe.contentWindow[0] to hide the property 0 added by the proxy
          if (key === '0') {
            return undefined;
          }
          return Reflect.get(target, key);
        }
      };

      if (!iframe.contentWindow) {
        const proxy = new Proxy(window, contentWindowProxy);
        Object.defineProperty(iframe, 'contentWindow', {
          get() {
            return proxy;
          },
          set(newValue) {
            return newValue; // contentWindow is immutable
          },
          enumerable: true,
          configurable: false
        });
      }
    };

    // Handles iframe element creation, augments srcdoc property
    const handleIframeCreation = (target, thisArg, args) => {
      const iframe = target.apply(thisArg, args);

      const _iframe = iframe;
      const _srcdoc = _iframe.srcdoc;

      // Add hook for the srcdoc property
      Object.defineProperty(iframe, 'srcdoc', {
        configurable: true,
        get: function() {
          return _srcdoc;
        },
        set: function(newValue) {
          addContentWindowProxy(this);
          // Reset property, the hook is only needed once
          Object.defineProperty(iframe, 'srcdoc', {
            configurable: false,
            writable: false,
            value: _srcdoc
          });
          _iframe.srcdoc = newValue;
        }
      });
      return iframe;
    };

    // Adds a hook to intercept iframe creation events
    const addIframeCreationSniffer = () => {
      const createElementHandler = {
        get(target, key) {
          return Reflect.get(target, key);
        },
        apply: function(target, thisArg, args) {
          const isIframe =
            args && args.length && `${args[0]}`.toLowerCase() === 'iframe';
          if (!isIframe) {
            return target.apply(thisArg, args);
          } else {
            return handleIframeCreation(target, thisArg, args);
          }
        }
      };
      utils.replaceWithProxy(
        document,
        'createElement',
        createElementHandler
      );
    };

    addIframeCreationSniffer();
  } catch (err) {
    // Silently fail
  }
})();
