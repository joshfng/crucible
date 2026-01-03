/**
 * Evasion: webgl.vendor
 * Fix WebGL Vendor/Renderer being set to Google in headless mode.
 * Default values match a typical Apple Retina MBP.
 */
(function(opts) {
  'use strict';

  const utils = window._stealthUtils;
  if (!utils) return;

  const vendor = opts.vendor || 'Intel Inc.';
  const renderer = opts.renderer || 'Intel Iris OpenGL Engine';

  const getParameterProxyHandler = {
    apply: function(target, ctx, args) {
      const param = (args || [])[0];
      const result = utils.cache.Reflect.apply(target, ctx, args);
      // UNMASKED_VENDOR_WEBGL
      if (param === 37445) {
        return vendor;
      }
      // UNMASKED_RENDERER_WEBGL
      if (param === 37446) {
        return renderer;
      }
      return result;
    }
  };

  // There's more than one WebGL rendering context
  const addProxy = (obj, propName) => {
    utils.replaceWithProxy(obj, propName, getParameterProxyHandler);
  };

  // Patch both WebGL contexts
  if (typeof WebGLRenderingContext !== 'undefined') {
    addProxy(WebGLRenderingContext.prototype, 'getParameter');
  }
  if (typeof WebGL2RenderingContext !== 'undefined') {
    addProxy(WebGL2RenderingContext.prototype, 'getParameter');
  }
})({ vendor: null, renderer: null }); // Will be replaced by Ruby
