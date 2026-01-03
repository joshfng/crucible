/**
 * Evasion: navigator.vendor
 * Override navigator.vendor to return the correct value.
 */
(function(opts) {
  'use strict';

  const utils = window._stealthUtils;
  if (!utils) return;

  const vendor = opts.vendor || 'Google Inc.';

  utils.replaceGetterWithProxy(
    Object.getPrototypeOf(navigator),
    'vendor',
    utils.makeHandler().getterValue(vendor)
  );
})({ vendor: null }); // Will be replaced by Ruby
