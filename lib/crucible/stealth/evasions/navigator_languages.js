/**
 * Evasion: navigator.languages
 * Override navigator.languages to match Accept-Language header.
 */
(function(opts) {
  'use strict';

  const utils = window._stealthUtils;
  if (!utils) return;

  const languages = opts.languages || ['en-US', 'en'];

  utils.replaceGetterWithProxy(
    Object.getPrototypeOf(navigator),
    'languages',
    utils.makeHandler().getterValue(Object.freeze([...languages]))
  );
})({ languages: null }); // Will be replaced by Ruby
