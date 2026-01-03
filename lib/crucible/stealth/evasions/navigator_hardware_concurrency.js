/**
 * Evasion: navigator.hardwareConcurrency
 * Set the hardwareConcurrency to a reasonable value (default: 4).
 */
(function(opts) {
  'use strict';

  const utils = window._stealthUtils;
  if (!utils) return;

  const hardwareConcurrency = opts.hardwareConcurrency || 4;

  utils.replaceGetterWithProxy(
    Object.getPrototypeOf(navigator),
    'hardwareConcurrency',
    utils.makeHandler().getterValue(hardwareConcurrency)
  );
})({ hardwareConcurrency: null }); // Will be replaced by Ruby
