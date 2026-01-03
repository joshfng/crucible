/**
 * Evasion: chrome.app
 * Mock the chrome.app object that exists in headed Chrome.
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

  if ('app' in window.chrome) {
    return; // Already exists
  }

  const makeError = {
    ErrorInInvocation: fn => {
      const err = new TypeError(`Error in invocation of app.${fn}()`);
      return err;
    }
  };

  const STATIC_DATA = {
    isInstalled: false,
    InstallState: {
      DISABLED: 'disabled',
      INSTALLED: 'installed',
      NOT_INSTALLED: 'not_installed'
    },
    RunningState: {
      CANNOT_RUN: 'cannot_run',
      READY_TO_RUN: 'ready_to_run',
      RUNNING: 'running'
    }
  };

  window.chrome.app = {
    ...STATIC_DATA,

    get isInstalled() {
      return false;
    },

    getDetails: function getDetails() {
      if (arguments.length) {
        throw makeError.ErrorInInvocation('getDetails');
      }
      return null;
    },

    getIsInstalled: function getIsInstalled() {
      if (arguments.length) {
        throw makeError.ErrorInInvocation('getIsInstalled');
      }
      return false;
    },

    runningState: function runningState() {
      if (arguments.length) {
        throw makeError.ErrorInInvocation('runningState');
      }
      return 'cannot_run';
    }
  };

  // Patch toString for native appearance
  if (window._stealthUtils) {
    window._stealthUtils.patchToStringNested(window.chrome.app);
  }
})();
