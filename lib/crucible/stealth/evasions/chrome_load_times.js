/**
 * Evasion: chrome.loadTimes
 * Mock the chrome.loadTimes function that exists in headed Chrome.
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

  if ('loadTimes' in window.chrome) {
    return; // Already exists
  }

  window.chrome.loadTimes = function loadTimes() {
    const now = Date.now() / 1000;
    const rand = Math.random();
    return {
      commitLoadTime: now - rand,
      connectionInfo: 'http/1.1',
      finishDocumentLoadTime: now - rand + 0.1,
      finishLoadTime: now - rand + 0.2,
      firstPaintAfterLoadTime: 0,
      firstPaintTime: now - rand + 0.05,
      navigationType: 'Other',
      npnNegotiatedProtocol: 'unknown',
      requestTime: now - rand - 0.1,
      startLoadTime: now - rand,
      wasAlternateProtocolAvailable: false,
      wasFetchedViaSpdy: false,
      wasNpnNegotiated: false
    };
  };

  if (window._stealthUtils) {
    window._stealthUtils.patchToString(window.chrome.loadTimes);
  }
})();
