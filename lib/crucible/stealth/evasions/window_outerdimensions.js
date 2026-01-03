/**
 * Evasion: window.outerdimensions
 * Fix missing window.outerWidth/window.outerHeight in headless mode.
 */
(function() {
  'use strict';

  try {
    if (window.outerWidth && window.outerHeight) {
      return; // Nothing to do here
    }
    const windowFrame = 85; // Approximate window frame size (OS/WM dependent)
    window.outerWidth = window.innerWidth;
    window.outerHeight = window.innerHeight + windowFrame;
  } catch (err) {
    // Silently fail
  }
})();
