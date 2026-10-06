(() => {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'fivex_knoway';
  const $ = (id) => document.getElementById(id);
  const post = (name, data) => fetch(`https://${resource}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).catch(() => {});

  const KEY_LABEL = { LMENU: 'ALT', RMENU: 'ALT', BACK: '⌫', RETURN: '↵', SPACE: 'SPACE' };
  const keyLabel = (k) => KEY_LABEL[k] || String(k || '').toUpperCase();

  function render(h) {
    const el = $('hud');
    if (!h || !h.show) { el.classList.add('hidden'); return; }
    el.classList.remove('hidden');
    $('h-title').textContent = h.title || '';
    $('h-sub').textContent = h.sub || '';
    const prog = $('h-progress');
    if (typeof h.progress === 'number') {
      prog.classList.remove('hidden');
      $('h-bar').style.width = Math.round(h.progress * 100) + '%';
    } else {
      prog.classList.add('hidden');
    }
    const showGo = h.state === 'arrived';
    $('h-go').classList.toggle('hidden', !showGo);
    $('h-go').disabled = !h.canGo;
    $('h-cancel').classList.toggle('hidden', !h.canCancel);
    $('h-actions').classList.toggle('hidden', !showGo && !h.canCancel);
    $('h-hint').classList.toggle('hidden', !showGo && !h.canCancel);
    $('h-pulse').classList.toggle('hidden', !['searching', 'dispatched', 'enroute'].includes(h.state));
    if (h.keys) {
      $('k-go').textContent = keyLabel(h.keys.go);
      $('k-cancel').textContent = keyLabel(h.keys.cancel);
      $('k-cursor').textContent = keyLabel(h.keys.cursor);
    }
  }

  $('h-go').addEventListener('click', () => post('hudGo'));
  $('h-cancel').addEventListener('click', () => post('hudCancel'));
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('hudCursorOff'); });

  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.type === 'hud') render(d.hud);
    else if (d.type === 'cursor') $('hud').classList.toggle('cursor', !!d.on);
  });
})();
