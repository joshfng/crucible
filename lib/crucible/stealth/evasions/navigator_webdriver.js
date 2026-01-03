/**
 * Evasion: navigator.webdriver
 * Deletes the navigator.webdriver property that reveals automation.
 */
(function() {
  'use strict';

  if (navigator.webdriver === false) {
    // Post Chrome 89.0.4339.0 and already good
  } else if (navigator.webdriver === undefined) {
    // Pre Chrome 89.0.4339.0 and already good
  } else {
    // Needs patching
    delete Object.getPrototypeOf(navigator).webdriver;
  }
})();
