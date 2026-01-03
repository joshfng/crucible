/**
 * Evasion: chrome.csi
 * Mock the chrome.csi function that exists in headed Chrome.
 */
(function() {
  'use strict';

  if (!window.chrome) {
    Object.defineProperty(window, 'chrome', {
      writable: true,
      enumerable: true,
      configurable: false,
      value: {}
    });
  }

  if ('csi' in window.chrome) {
    return; // Already exists
  }

  window.chrome.csi = function csi() {
    return {
      onloadT: Date.now(),
      startE: Date.now(),
      pageT: Math.random() * 1000 + 100,
      tran: 15
    };
  };

  if (window._stealthUtils) {
    window._stealthUtils.patchToString(window.chrome.csi);
  }
})();
