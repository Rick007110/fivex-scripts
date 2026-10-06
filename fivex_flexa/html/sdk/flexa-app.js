/*
 * Flexa App SDK — include in your app page:
 *   <script src="https://cfx-nui-fivex_flexa/html/sdk/flexa-app.js"></script>
 *
 *   FlexaApp.resource                 your resource name (from the page origin)
 *   FlexaApp.post(name, data)         -> Promise; calls RegisterNUICallback(name) in YOUR resource
 *   FlexaApp.on(event, fn)            'init' {app, theme, folded, number, clockFormat}
 *                                     'message' data   (exports.fivex_flexa:SendAppMessage(id, data))
 *                                     'theme' 'dark'|'light'
 *                                     'visibility' true|false (phone opened / closed)
 *   FlexaApp.toast(text)              phone toast
 *   FlexaApp.back() / FlexaApp.home() phone navigation
 *   FlexaApp.vibrate()
 *   FlexaApp.theme                    current theme; also set as <html data-theme="dark|light">
 */
(function () {
  'use strict';
  const host = location.hostname || '';
  const resource = host.indexOf('cfx-nui-') === 0
    ? host.slice('cfx-nui-'.length)
    : (typeof GetParentResourceName === 'function' ? GetParentResourceName() : host);

  const listeners = {};
  const state = { ready: false, app: null, theme: 'dark', folded: true, number: null, clockFormat: '24h' };

  function emit(type, payload) {
    (listeners[type] || []).slice().forEach((fn) => {
      try { fn(payload); } catch (e) { console.error('[FlexaApp]', type, e); }
    });
  }

  function setTheme(theme) {
    state.theme = theme === 'light' ? 'light' : 'dark';
    document.documentElement.dataset.theme = state.theme;
  }

  function toPhone(type, extra) {
    if (window.parent && window.parent !== window) {
      window.parent.postMessage(Object.assign({ __flexa: true, type }, extra || {}), '*');
    }
  }

  // Flexa 4: apps run inside sd-phone / sd-tablet (exports.fivex_flexa:RegisterApp makes them
  // sd custom apps). Their shell speaks its own protocol, so translate it to the same events.
  let sdHost = false;
  // sd gives an app the whole screen, status bar and home indicator included (old Flexa kept those
  // outside the page). Pad the page so its own header clears the status bar / Dynamic Island.
  function enterSd() {
    if (sdHost) return;
    sdHost = true;
    const css = document.createElement('style');
    css.textContent = 'html.flexa-in-sd body { box-sizing: border-box; padding-top: 54px !important; padding-bottom: 24px !important; }'
      // unfolded (880 wide): Flexa apps were laid out for at most the old 720px unfolded screen
      + '@media (min-width: 760px) { html.flexa-in-sd body { max-width: 720px; margin-left: auto !important; margin-right: auto !important; } }';
    (document.head || document.documentElement).appendChild(css);
    document.documentElement.classList.add('flexa-in-sd');
  }
  window.addEventListener('message', (ev) => {
    const m = ev.data;
    if (!m || typeof m !== 'object' || ev.source !== window.parent || m.__flexa === true) return;
    if (m.type === 'settingsUpdated' && m.settings) {
      const theme = m.settings.theme || (m.settings.display && m.settings.display.theme);
      const first = !state.ready;
      enterSd();
      setTheme(theme);
      if (first) {
        state.ready = true;
        state.clockFormat = m.settings.time && m.settings.time.hour24 ? '24h' : '12h';
        emit('init', Object.assign({}, state));
      } else emit('theme', state.theme);
    } else if (m.type === 'appOpen') {
      enterSd(); emit('visibility', true);
    } else if (m.type === 'appClose') {
      emit('visibility', false);
    } else if (m.action === 'flexa:message') {
      enterSd(); emit('message', m.data);
    }
  });
  // sd's SDK is injected into the page by the shell; it may also already have settings for us
  setTimeout(() => {
    if (window.components || window.settings) enterSd();
    if (!state.ready && window.settings && typeof window.settings === 'object') {
      state.ready = true; setTheme(window.settings.theme);
      emit('init', Object.assign({}, state));
    }
  }, 300);
  // never leave a page waiting for an init that no host sends
  setTimeout(() => { if (!state.ready) { state.ready = true; emit('init', Object.assign({}, state)); } }, 1500);

  window.addEventListener('message', (ev) => {
    const m = ev.data;
    if (!m || m.__flexa !== true || ev.source !== window.parent) return;
    if (m.type === 'init') {
      Object.assign(state, { ready: true, app: m.app || null, folded: !!m.folded, number: m.number || null, clockFormat: m.clockFormat || '24h' });
      setTheme(m.theme);
      emit('init', Object.assign({}, state));
    } else if (m.type === 'theme') {
      setTheme(m.theme);
      emit('theme', state.theme);
    } else if (m.type === 'message') {
      emit('message', m.data);
    } else if (m.type === 'visibility') {
      emit('visibility', !!m.visible);
    }
  });

  window.FlexaApp = {
    resource,
    get theme() { return state.theme; },
    get app() { return state.app; },
    get ready() { return state.ready; },
    post(name, data) {
      return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data == null ? {} : data),
      }).then((r) => r.json().catch(() => ({}))).catch(() => ({ ok: false }));
    },
    on(type, fn) {
      (listeners[type] = listeners[type] || []).push(fn);
      if (type === 'init' && state.ready) fn(Object.assign({}, state));
      return () => { listeners[type] = (listeners[type] || []).filter((f) => f !== fn); };
    },
    toast(text) {
      text = String(text == null ? '' : text);
      if (sdHost) {
        // the shell injects a bridge into the page; sd's own SDK sends notifications through it too
        const bridge = window.components;
        if (bridge && typeof bridge.fetchPhone === 'function') {
          try { bridge.fetchPhone('SendNotification', { title: window.appName || 'App', content: text, app: window.appIdentifier }); } catch (e) { /* ignore */ }
        }
        return;
      }
      toPhone('toast', { text });
    },
    back() { toPhone('back'); },
    home() { toPhone('home'); },
    vibrate() { toPhone('vibrate'); },
  };

  setTheme('dark');
  toPhone('ready');
})();
