(() => {
  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'fivex_spawn';
  const $ = (id) => document.getElementById(id);
  const post = (name, data) => fetch(`https://${resource}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  }).then((r) => r.json()).catch(() => ({}));
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  const ICONS = {
    history: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    city: '<path d="M3 21V9l6-3v15M9 21V4l8 4v13M21 21V12l-4-2M6 12h.01M6 16h.01M13 10h.01M13 14h.01M13 18h.01M3 21h18"/>',
    hospital: '<rect x="3" y="3" width="18" height="18" rx="4"/><path d="M12 8v8M8 12h8"/>',
    police: '<path d="M12 3l8 3v6c0 4.5-3.4 8.3-8 9-4.6-.7-8-4.5-8-9V6z"/><path d="m9 12 2 2 4-4"/>',
    briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18"/>',
    car: '<path d="M3 16v-3l2.4-4.6h13.2L21 13v3"/><path d="M2.5 16h19"/><circle cx="7" cy="16.5" r="1.8"/><circle cx="17" cy="16.5" r="1.8"/>',
    plane: '<path d="M10.5 21 12 17l1.5 4M12 17V4a1.5 1.5 0 0 0-3 0v5L3 13v2l6-2v4l-2 1.5V20l3-1"/><path d="M12 9l6 4v2l-6-2"/>',
    pier: '<path d="M2 20c2 0 2-1.5 4-1.5S8 20 10 20s2-1.5 4-1.5S16 20 18 20s2-1.5 4-1.5M4 16V8M10 16V8M16 16V8M2 8h20"/><circle cx="18" cy="4" r="1.5"/>',
    star: '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
    desert: '<path d="M3 20h18M8 20V9a2 2 0 0 1 4 0v11M8 13H6a2 2 0 0 1-2-2V9M12 11h2a2 2 0 0 0 2-2V7"/><circle cx="18" cy="4" r="1.5"/>',
    forest: '<path d="m7 3-4 7h3l-3 5h8l-3-5h3zM7 15v6M17 6l-3 5h2l-3 5h8l-3-5h2zM17 16v5"/>',
    pin: '<path d="M12 22s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12z"/><circle cx="12" cy="10" r="2.5"/>',
  };
  const icon = (n) => `<svg viewBox="0 0 24 24">${ICONS[n] || ICONS.pin}</svg>`;

  let choices = [];
  let index = 0;
  let open = false;
  let busy = false;
  let previewTimer = 0;

  function renderList() {
    $('list').innerHTML = choices.map((c, i) => `
      <button type="button" class="item ${c.id === 'last' ? 'last' : ''}" role="option" data-i="${i}" aria-selected="${i === index}">
        <span class="ico">${icon(c.icon)}</span>
        <span class="meta"><div class="name">${esc(c.label)}</div><div class="area">${esc(c.area || '')}</div></span>
        ${c.id === 'last' ? '<span class="tag">Resume</span>' : ''}
      </button>`).join('');
    $('list').querySelectorAll('[data-i]').forEach((b) => b.addEventListener('click', () => select(Number(b.dataset.i))));
  }

  function select(i) {
    if (busy || i < 0 || i >= choices.length) return;
    const changed = i !== index;
    index = i;
    $('list').querySelectorAll('[data-i]').forEach((b) => b.setAttribute('aria-selected', String(Number(b.dataset.i) === index)));
    const sel = $('list').querySelector(`[data-i="${index}"]`);
    if (sel) sel.scrollIntoView({ block: 'nearest' });
    const c = choices[index];
    $('place-area').textContent = c.area || '';
    $('place-name').textContent = c.label;
    $('spawn-sub').textContent = c.label;
    if (changed) {
      const place = document.querySelector('.place');
      place.classList.remove('swap'); void place.offsetWidth; place.classList.add('swap');
      // debounce so arrowing through the list doesn't queue a camera move per step
      clearTimeout(previewTimer);
      previewTimer = setTimeout(() => post('preview', { index: index + 1 }), 180);
    }
  }

  function spawn() {
    if (busy || !open) return;
    busy = true;
    $('spawn').disabled = true;
    post('spawn', { index: index + 1 });
  }

  $('spawn').addEventListener('click', spawn);
  document.addEventListener('keydown', (e) => {
    if (!open) return;
    if (e.key === 'ArrowDown') { e.preventDefault(); select(Math.min(choices.length - 1, index + 1)); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); select(Math.max(0, index - 1)); }
    else if (e.key === 'Enter') { e.preventDefault(); spawn(); }
  });

  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.type === 'open') {
      choices = Array.isArray(d.choices) ? d.choices : Object.values(d.choices || {});
      index = 0;
      busy = false;
      open = true;
      $('spawn').disabled = false;
      $('welcome').textContent = d.name ? `Welcome back, ${d.name}` : 'Welcome';
      renderList();
      select(0);
      $('screen').classList.remove('hidden');
    } else if (d.type === 'close') {
      open = false;
      $('screen').classList.add('hidden');
    }
  });
})();
