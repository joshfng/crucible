/**
 * Evasion: navigator.permissions
 * Fix Notification.permission behaving weirdly in headless mode.
 * On secure origins the permission should be "default", not "denied".
 */
(function() {
  'use strict';

  const utils = window._stealthUtils;
  if (!utils) return;

  const isSecure = document.location.protocol.startsWith('https');

  // In headful on secure origins the permission should be "default", not "denied"
  if (isSecure) {
    if (typeof Notification !== 'undefined') {
      utils.replaceGetterWithProxy(Notification, 'permission', {
        apply() {
          return 'default';
        }
      });
    }
  }

  // On insecure origins in headful the state is "denied",
  // whereas in headless it's "prompt"
  if (!isSecure) {
    if (typeof Permissions !== 'undefined' && typeof PermissionStatus !== 'undefined') {
      const handler = {
        apply(target, ctx, args) {
          const param = (args || [])[0];

          const isNotifications =
            param && param.name && param.name === 'notifications';
          if (!isNotifications) {
            return utils.cache.Reflect.apply(...arguments);
          }

          return Promise.resolve(
            Object.setPrototypeOf(
              {
                state: 'denied',
                onchange: null
              },
              PermissionStatus.prototype
            )
          );
        }
      };
      utils.replaceWithProxy(Permissions.prototype, 'query', handler);
    }
  }
})();
