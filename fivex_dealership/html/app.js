(() => {
  const resource = (typeof GetParentResourceName === 'function')
    ? GetParentResourceName()
    : 'fivex_dealership';

  const $ = (id) => document.getElementById(id);
  const fmt = new Intl.NumberFormat('en-US');
  const money = (n) => '$' + fmt.format(Math.max(0, Math.floor(Number(n) || 0)));

  const ICONS = {
    compacts: '<path d="M4.5 16v-3l2.4-4.5h9.2L18.5 13v3"/><path d="M3 16h17"/><circle cx="7.5" cy="16.5" r="1.8"/><circle cx="15.5" cy="16.5" r="1.8"/>',
    sedans: '<path d="M2.5 16v-2.5l3-5h11l3.5 5H22v2.5"/><path d="M2 16h20"/><circle cx="7" cy="16.5" r="1.8"/><circle cx="17" cy="16.5" r="1.8"/>',
    suvs: '<path d="M3 16V8.5h13l3.5 4.5H21v3"/><path d="M2.5 16h19M9.5 8.5V13M3 13h18"/><circle cx="7" cy="16.5" r="1.8"/><circle cx="17" cy="16.5" r="1.8"/>',
    coupes: '<path d="M2 16v-2l4-4.5h7l5 4.5 4 .5V16"/><path d="M2 16h20"/><circle cx="6.5" cy="16.5" r="1.8"/><circle cx="17.5" cy="16.5" r="1.8"/>',
    muscle: '<path d="M12 21c-3.5 0-6-2.4-6-5.6 0-3.3 2.6-5.1 3.6-8.4.4 1.8 1.5 2.8 2.4 3.4.3-2.3 1.3-4.5 3-6.4.4 3.4 3 5.6 3 9.6 0 4.1-2.6 7.4-6 7.4z"/>',
    sports: '<path d="M4.5 17a8.5 8.5 0 1 1 15 0"/><path d="M12 13l4-4"/><circle cx="12" cy="13" r="1.3"/>',
    super: '<path d="M13 2.5 5 13.5h6l-1 8 8-11h-6l1-8z"/>',
    motorcycles: '<circle cx="5.5" cy="16" r="3.2"/><circle cx="18.5" cy="16" r="3.2"/><path d="M5.5 16 9 10h5l4.5 6M14 10l-1.5-3H10M9 10l3 6h6.5"/>',
    offroad: '<path d="M2 19 9 8l4 6 2.5-3.5L22 19z"/>',
    vans: '<path d="M2.5 16V7h12.5l4.5 4.5H21.5V16"/><path d="M2 16h20M15 7v4.5h6"/><circle cx="7" cy="16.5" r="1.8"/><circle cx="17" cy="16.5" r="1.8"/>',
    classics: '<path d="M2 16v-2.5l2.5-4 3.5-1.5h5l3.5 3.5 5 1V16"/><path d="M2 16h20"/><circle cx="6.5" cy="16.5" r="1.8"/><circle cx="17.5" cy="16.5" r="1.8"/>',
    cycles: '<circle cx="5.5" cy="16" r="3.5"/><circle cx="18.5" cy="16" r="3.5"/><path d="M5.5 16 9.5 9h6l3 7M9.5 9 12 16h1.5M8 6.5h3M15.5 9l-1-3H17"/>',
    utility: '<path d="M14.5 6.5a3.5 3.5 0 0 0-4.6 4.4L4 16.8 7.2 20l5.9-5.9a3.5 3.5 0 0 0 4.4-4.6l-2.1 2.1-2.4-.6-.6-2.4z"/>',
    commercial: '<path d="M2.5 16V6h11v10M13.5 9.5h4l3.5 3.5V16"/><path d="M2 16h20"/><circle cx="6.5" cy="16.5" r="1.8"/><circle cx="17.5" cy="16.5" r="1.8"/>',
    industrial: '<path d="M3 17V11h7l2-4h3l5 6v4"/><path d="M15 7l3.5-3.5M2.5 17h19"/><circle cx="6.5" cy="17.5" r="1.8"/><circle cx="17" cy="17.5" r="1.8"/>',
    service: '<rect x="3" y="4" width="18" height="12.5" rx="2"/><path d="M3 11h18M7.5 4v7M2.5 16.5h19"/><circle cx="7" cy="18" r="1.5"/><circle cx="17" cy="18" r="1.5"/>',
    openwheel: '<path d="M3 17h18M5 17v-3h3l3-3h3l2 3h3v3"/><circle cx="5.5" cy="17.5" r="2"/><circle cx="18.5" cy="17.5" r="2"/><path d="M11 11V8h4"/>',
    _default: '<path d="M2.5 16v-2.5l3-5h11l3.5 5H22v2.5"/><path d="M2 16h20"/><circle cx="7" cy="16.5" r="1.8"/><circle cx="17" cy="16.5" r="1.8"/>',
  };
  const icon = (id) => `<svg viewBox="0 0 24 24" aria-hidden="true">${ICONS[id] || ICONS._default}</svg>`;

  let state = {
    open: false, kind: 'showroom', location: '', vehicles: [], bank: 0, cash: 0, max: 10, fee: 0,
    catalog: [], categories: [], colors: [],
  };
  let category = null;
  let selected = null;
  let color = 0;
  let method = 'bank';
  let query = '';
  let sort = 'price-asc';
  let garageFilter = 'all';
  let busy = false;
  let previewSeq = 0;
  let lastStats = null;
  let pending = null;

  // Lua sends empty tables as {} — coerce list fields to arrays.
  const LISTS = ['vehicles', 'catalog', 'categories', 'colors'];
  function merge(d) {
    const next = Object.assign({}, state, d || {});
    LISTS.forEach((k) => {
      const v = next[k];
      next[k] = Array.isArray(v) ? v : Object.values(v || {});
    });
    return next;
  }

  function post(name, data) {
    return fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({ ok: false }));
  }

  function escapeHtml(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  function toast(message, level) {
    const el = document.createElement('div');
    el.className = 'toast ' + (level || 'info');
    el.innerHTML = `<i></i><span>${escapeHtml(message)}</span>`;
    $('toasts').appendChild(el);
    setTimeout(() => el.classList.add('out'), 3800);
    setTimeout(() => el.remove(), 4100);
  }

  // "Karin Sultan" -> ["Karin", "Sultan"]
  function split(label) {
    const s = String(label || '');
    const i = s.indexOf(' ');
    return i > 0 ? [s.slice(0, i), s.slice(i + 1)] : ['', s];
  }

  // brand/model split: use the catalog's manufacturer when we have it
  function parts(v) {
    if (v && v.brand && v.label && v.label.startsWith(v.brand + ' ')) return [v.brand, v.label.slice(v.brand.length + 1)];
    if (v && v.brand === '') return ['', v.label || ''];
    return split(v && v.label);
  }

  const entryOf = (model) => state.catalog.find((v) => v.model === model);
  const colorOf = (id) => state.colors.find((c) => c.id === id);
  const catLabel = (id) => (state.categories.find((c) => c.id === id) || {}).label || id;
  const ownedCount = (model) => state.vehicles.filter((v) => v.model === model).length;

  /* ---------- modal ---------- */

  function confirmModal({ eyebrow, title, body, rows, ok, danger, action }) {
    $('modal-eyebrow').textContent = eyebrow || 'Confirm';
    $('modal-title').textContent = title;
    $('modal-body').textContent = body || '';
    const sum = $('modal-summary');
    if (rows && rows.length) {
      sum.innerHTML = rows.map(([k, v]) => `<span>${escapeHtml(k)}</span><b>${escapeHtml(v)}</b>`).join('');
      sum.classList.remove('hidden');
    } else {
      sum.classList.add('hidden');
    }
    const okBtn = $('modal-ok');
    okBtn.textContent = ok || 'Confirm';
    okBtn.classList.toggle('danger', !!danger);
    pending = action;
    $('modal').classList.remove('hidden');
  }

  function closeModal() {
    pending = null;
    $('modal').classList.add('hidden');
  }

  function act(name, data) {
    if (busy) return;
    busy = true;
    render();
    post(name, data).then(() => {
      busy = false;
      render();
    });
  }

  /* ---------- showroom ---------- */

  function visibleList() {
    const q = query.trim().toLowerCase();
    let list = q
      ? state.catalog.filter((v) => v.label.toLowerCase().includes(q) || v.model.toLowerCase().includes(q))
      : state.catalog.filter((v) => v.category === category);
    list = list.slice();
    if (sort === 'price-asc') list.sort((a, b) => a.price - b.price);
    else if (sort === 'price-desc') list.sort((a, b) => b.price - a.price);
    else list.sort((a, b) => a.label.localeCompare(b.label));
    return list;
  }

  function renderRail() {
    const rail = $('rail');
    rail.classList.toggle('searching', query.trim() !== '');
    rail.innerHTML = state.categories.map((c) => {
      const n = state.catalog.filter((v) => v.category === c.id).length;
      if (!n) return '';
      return `<button type="button" class="rail-btn" data-cat="${escapeHtml(c.id)}" aria-pressed="${c.id === category}">
        ${icon(c.id)}<span>${escapeHtml(c.label)}</span><span class="count">${n}</span></button>`;
    }).join('');
    rail.querySelectorAll('[data-cat]').forEach((b) => b.addEventListener('click', () => {
      category = b.dataset.cat;
      query = '';
      $('d-search').value = '';
      renderRail();
      renderCarousel();
      const first = visibleList()[0];
      if (first) select(first.model);
    }));
  }

  function renderCarousel() {
    const list = visibleList();
    const q = query.trim();
    $('d-title').textContent = q ? `Results for “${q}”` : catLabel(category);
    $('d-count').textContent = `${list.length} vehicle${list.length === 1 ? '' : 's'}`;
    const best = Math.max(state.bank, state.cash);
    const el = $('carousel');
    if (!list.length) {
      el.innerHTML = '<div class="empty-state">No vehicles match your search.</div>';
      return;
    }
    el.innerHTML = list.map((v) => {
      const [brand, model] = parts(v);
      const owned = ownedCount(v.model);
      const tag = owned
        ? `<span class="vcard-tag">Owned${owned > 1 ? ' ×' + owned : ''}</span>`
        : (q ? `<span class="vcard-cat">${escapeHtml(catLabel(v.category))}</span>` : '');
      return `<button type="button" class="vcard" role="option" data-model="${escapeHtml(v.model)}" aria-selected="${v.model === selected}">
        <div><div class="vcard-brand">${escapeHtml(brand || catLabel(v.category))}</div>
        <div class="vcard-name">${escapeHtml(model)}</div></div>
        <div class="vcard-bottom"><span class="vcard-price ${v.price > best ? 'short' : ''}">${money(v.price)}</span>${tag}</div>
      </button>`;
    }).join('');
    el.querySelectorAll('[data-model]').forEach((b) => b.addEventListener('click', () => select(b.dataset.model)));
  }

  function scrollToSelected() {
    const card = $('carousel').querySelector('[aria-selected="true"]');
    if (card) card.scrollIntoView({ block: 'nearest', inline: 'center' });
  }

  function setStats(stats) {
    lastStats = stats;
    const box = $('i-stats');
    box.classList.toggle('loading', !stats);
    document.querySelectorAll('#i-stats [data-bar]').forEach((el) => {
      const v = stats && stats.bars ? Number(stats.bars[el.dataset.bar]) || 0 : 0;
      el.style.width = Math.round(v * 100) + '%';
    });
    document.querySelectorAll('#i-stats [data-num]').forEach((el) => {
      const v = stats && stats.bars ? Number(stats.bars[el.dataset.num]) || 0 : null;
      el.textContent = v === null ? '—' : (v * 10).toFixed(1);
    });
    $('v-speed').textContent = stats ? `${stats.speed} ${stats.unit}` : '—';
    renderMeta();
  }

  function renderMeta() {
    const v = entryOf(selected);
    if (!v) { $('i-meta').textContent = '—'; return; }
    const parts = [catLabel(v.category)];
    if (lastStats && lastStats.seats) parts.push(`${lastStats.seats} seat${lastStats.seats === 1 ? '' : 's'}`);
    const owned = ownedCount(v.model);
    if (owned) parts.push(`You own ${owned}`);
    $('i-meta').textContent = parts.join('  ·  ');
  }

  function renderInfo() {
    const v = entryOf(selected);
    const [brand, model] = v ? parts(v) : ['—', '—'];
    $('i-brand').textContent = brand || (v ? catLabel(v.category) : '—');
    $('i-model').textContent = model;
    $('i-price').textContent = v ? money(v.price) : '—';
    renderMeta();

    // paint
    const sw = $('swatches');
    sw.innerHTML = state.colors.map((c) =>
      `<button type="button" class="swatch" role="radio" data-color="${c.id}" title="${escapeHtml(c.label)}"
        aria-label="${escapeHtml(c.label)}" aria-checked="${c.id === color}" style="background:${escapeHtml(c.hex)}"></button>`).join('');
    sw.querySelectorAll('[data-color]').forEach((b) => b.addEventListener('click', () => {
      color = Number(b.dataset.color);
      renderInfo();
      post('color', { color });
    }));
    const c = colorOf(color);
    $('i-paint').textContent = c ? c.label : '—';

    // payment
    const price = v ? v.price : 0;
    const can = { bank: state.bank >= price, cash: state.cash >= price };
    if (!can[method] && can[method === 'bank' ? 'cash' : 'bank']) method = method === 'bank' ? 'cash' : 'bank';
    $('seg-bank').textContent = money(state.bank);
    $('seg-cash').textContent = money(state.cash);
    document.querySelectorAll('.segmented [data-method]').forEach((b) => {
      const m = b.dataset.method;
      b.setAttribute('aria-checked', m === method ? 'true' : 'false');
      b.classList.toggle('short', !!v && !can[m]);
    });

    const full = state.vehicles.length >= state.max;
    const buy = $('i-buy');
    let text = v ? `Purchase  ·  ${money(price)}` : 'Purchase';
    let fine = 'Delivered outside  ·  unique plate assigned';
    if (full) { text = 'Garage full'; fine = `You own ${state.max} vehicles — sell one first.`; }
    else if (v && !can[method]) { text = 'Insufficient funds'; fine = `You need ${money(price - (method === 'bank' ? state.bank : state.cash))} more ${method === 'bank' ? 'in the bank' : 'in cash'}.`; }
    buy.textContent = text;
    buy.disabled = busy || !v || full || !can[method];
    $('i-fine').textContent = fine;
  }

  function select(model) {
    selected = model;
    renderCarousel();
    renderInfo();
    scrollToSelected();
    const seq = ++previewSeq;
    setStats(null);
    post('preview', { model, color }).then((res) => {
      if (seq !== previewSeq) return;
      setStats(res && res.ok ? res.stats : null);
      if (!res || !res.ok) $('i-stats').classList.remove('loading');
    });
  }

  function step(dir) {
    const list = visibleList();
    if (!list.length) return;
    const i = list.findIndex((v) => v.model === selected);
    const next = list[(i + dir + list.length) % list.length];
    if (next) select(next.model);
  }

  function buy() {
    const v = entryOf(selected);
    if (!v) return;
    const c = colorOf(color);
    confirmModal({
      eyebrow: 'Purchase',
      title: v.label,
      body: 'The vehicle is delivered outside the showroom with a new plate.',
      rows: [
        ['Price', money(v.price)],
        ['Paint', c ? c.label : '—'],
        ['Payment', method === 'bank' ? 'Card (bank)' : 'Cash'],
        ['Balance after', money((method === 'bank' ? state.bank : state.cash) - v.price)],
      ],
      ok: `Pay ${money(v.price)}`,
      action: () => act('buy', { model: v.model, color, method }),
    });
  }

  /* ---------- owned / garage rows ---------- */

  const STATUS = { stored: 'Stored', out: 'Out', lost: 'Lost' };

  function condBar(label, pct) {
    const p = Math.max(0, Math.min(100, Number(pct) || 0));
    const cls = p >= 70 ? 'good' : (p >= 35 ? 'mid' : 'low');
    return `<div class="stat"><div class="stat-top"><span>${label}</span><b>${p}%</b></div>
      <div class="meter"><span class="${cls}" style="width:${p}%"></span></div></div>`;
  }

  function vehicleRow(v, actions, i) {
    const [brand, model] = parts(v);
    const c = colorOf(v.color);
    return `<div class="vrow" style="--paint:${escapeHtml(c ? c.hex : '#888')};animation-delay:${Math.min(i, 8) * 35}ms">
      <div class="vrow-top">
        <div>
          <div class="vrow-brand">${escapeHtml([brand, c && c.label].filter(Boolean).join(' · '))}</div>
          <div class="vrow-name">${escapeHtml(model)}</div>
        </div>
        <span class="status ${escapeHtml(v.status)}">${STATUS[v.status] || escapeHtml(v.status)}</span>
      </div>
      <div class="vrow-tags"><span class="plate">${escapeHtml(v.plate)}</span></div>
      <div class="cond">${condBar('Engine', v.engine)}${condBar('Body', v.body)}</div>
      <div class="vrow-actions">${actions}</div>
    </div>`;
  }

  function emptyList(title, text) {
    return `<div class="empty-list">${icon('_default')}<b>${escapeHtml(title)}</b><span>${escapeHtml(text)}</span></div>`;
  }

  function bindRowActions(root) {
    root.querySelectorAll('[data-act]').forEach((b) => b.addEventListener('click', () => {
      const v = state.vehicles.find((x) => x.plate === b.dataset.plate);
      if (!v || busy) return;
      const a = b.dataset.act;
      if (a === 'sell') {
        confirmModal({
          eyebrow: 'Sell vehicle', title: v.label,
          body: 'The dealership buys it back. This cannot be undone.',
          rows: [['Plate', v.plate], ['You receive', money(v.value)], ['Paid to', 'Bank']],
          ok: `Sell for ${money(v.value)}`, danger: true,
          action: () => act('sell', { plate: v.plate }),
        });
      } else if (a === 'recover') {
        const recall = v.status === 'out';
        confirmModal({
          eyebrow: recall ? 'Recall vehicle' : 'Recover vehicle', title: v.label,
          body: recall
            ? 'Your vehicle is brought back here from wherever it is.'
            : 'Your vehicle was lost or wrecked. It is brought back here fully repaired.',
          rows: [['Plate', v.plate], ['Fee', money(state.fee)], ['Paid from', 'Bank, then cash']],
          ok: `Pay ${money(state.fee)}`,
          action: () => act('recover', { plate: v.plate }),
        });
      } else if (a === 'takeout') {
        act('takeout', { plate: v.plate });
      }
    }));
  }

  function renderOwned() {
    $('owned-count').textContent = `${state.vehicles.length}/${state.max}`;
    const el = $('owned-list');
    if (!state.vehicles.length) {
      el.innerHTML = emptyList('No vehicles yet', 'Pick one from the showroom to get started.');
      return;
    }
    el.innerHTML = state.vehicles.map((v, i) => {
      const canSell = v.status === 'stored' && v.value > 0;
      const label = v.value > 0 ? `Sell for ${money(v.value)}` : 'No resale value';
      const why = v.status !== 'stored' ? 'title="Park it in a garage first"' : '';
      return vehicleRow(v, `<button type="button" class="btn-row danger" data-act="sell" data-plate="${escapeHtml(v.plate)}"
        ${why} ${canSell && !busy ? '' : 'disabled'}>${label}</button>`, i);
    }).join('');
    bindRowActions(el);
  }

  function renderGarage() {
    $('g-location').textContent = state.location || 'Garage';
    $('g-bank').textContent = money(state.bank);
    $('g-cash').textContent = money(state.cash);
    $('g-owned').textContent = `${state.vehicles.length}/${state.max}`;
    document.querySelectorAll('#g-filters [data-filter]').forEach((b) => {
      b.setAttribute('aria-selected', b.dataset.filter === garageFilter ? 'true' : 'false');
    });

    const el = $('garage-list');
    const anyOut = state.vehicles.some((v) => v.status === 'out');
    const list = state.vehicles.filter((v) => garageFilter === 'all'
      || (garageFilter === 'stored' ? v.status === 'stored' : v.status !== 'stored'));
    if (!state.vehicles.length) {
      el.innerHTML = emptyList('No vehicles', 'Buy one at Premium Deluxe Motorsport.');
    } else if (!list.length) {
      el.innerHTML = emptyList('Nothing here', garageFilter === 'stored' ? 'All your vehicles are out.' : 'Every vehicle is parked.');
    } else {
      el.innerHTML = list.map((v, i) => {
        const p = escapeHtml(v.plate);
        let btn;
        if (v.status === 'stored') {
          btn = `<button type="button" class="btn-row primary" data-act="takeout" data-plate="${p}"
            ${busy || anyOut ? 'disabled' : ''}>${anyOut ? 'Another vehicle is out' : 'Take out'}</button>`;
        } else if (v.status === 'out') {
          btn = `<button type="button" class="btn-row" data-act="recover" data-plate="${p}" ${busy ? 'disabled' : ''}>Recall · ${money(state.fee)}</button>`;
        } else {
          btn = `<button type="button" class="btn-row warn" data-act="recover" data-plate="${p}" ${busy ? 'disabled' : ''}>Recover &amp; repair · ${money(state.fee)}</button>`;
        }
        return vehicleRow(v, btn, i);
      }).join('');
    }
    $('garage-note').textContent = anyOut
      ? 'One vehicle out at a time. Park it at any garage, or recall it here.'
      : 'Drive an owned vehicle onto a garage marker and press E to park it.';
    bindRowActions(el);
  }

  /* ---------- shell ---------- */

  function render() {
    const showroom = state.kind === 'showroom';
    $('showroom').classList.toggle('hidden', !showroom || !state.open);
    $('garage').classList.toggle('hidden', showroom || !state.open);
    if (showroom) {
      $('s-location').textContent = state.location || '';
      $('s-bank').textContent = money(state.bank);
      $('s-cash').textContent = money(state.cash);
      renderCarousel();
      renderInfo();
      renderOwned();
    } else {
      renderGarage();
    }
  }

  function openUi(payload) {
    state = merge(payload);
    state.open = true;
    busy = false;
    closeModal();
    $('drawer').classList.add('hidden');
    if (state.kind === 'showroom') {
      query = '';
      $('d-search').value = '';
      if (!category || !state.catalog.some((v) => v.category === category)) {
        category = (state.categories.find((c) => state.catalog.some((v) => v.category === c.id)) || {}).id;
      }
      if (!colorOf(color)) color = (state.colors[0] || {}).id || 0;
      renderRail();
    } else {
      garageFilter = 'all';
    }
    render();
    if (state.kind === 'showroom') {
      const keep = entryOf(selected);
      const first = keep && keep.category === category ? keep : visibleList()[0];
      if (first) select(first.model);
    }
  }

  function hideAll() {
    state.open = false;
    $('showroom').classList.add('hidden');
    $('garage').classList.add('hidden');
    closeModal();
  }

  function closeUi() {
    hideAll();
    post('close', {});
  }

  // controls
  $('s-close').addEventListener('click', closeUi);
  $('g-close').addEventListener('click', closeUi);
  $('i-buy').addEventListener('click', buy);
  $('btn-owned').addEventListener('click', () => $('drawer').classList.toggle('hidden'));
  $('drawer-close').addEventListener('click', () => $('drawer').classList.add('hidden'));
  document.querySelectorAll('.segmented [data-method]').forEach((b) => b.addEventListener('click', () => {
    method = b.dataset.method;
    renderInfo();
  }));
  document.querySelectorAll('#g-filters [data-filter]').forEach((b) => b.addEventListener('click', () => {
    garageFilter = b.dataset.filter;
    renderGarage();
  }));
  $('d-search').addEventListener('input', (e) => {
    query = e.target.value;
    renderRail();
    renderCarousel();
    const list = visibleList();
    if (list.length && !list.some((v) => v.model === selected)) select(list[0].model);
  });
  $('d-sort').addEventListener('change', (e) => {
    sort = e.target.value;
    renderCarousel();
    scrollToSelected();
  });
  $('modal-cancel').addEventListener('click', closeModal);
  $('modal-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const fn = pending;
    closeModal();
    if (fn) fn();
  });

  // drag to rotate the preview car
  const stage = $('stage');
  let dragging = false;
  let lastX = 0;
  let acc = 0;
  let raf = 0;
  stage.addEventListener('mousedown', (e) => {
    dragging = true;
    lastX = e.clientX;
    stage.classList.add('dragging');
  });
  window.addEventListener('mouseup', () => {
    dragging = false;
    stage.classList.remove('dragging');
  });
  window.addEventListener('mousemove', (e) => {
    if (!dragging) return;
    acc += e.clientX - lastX;
    lastX = e.clientX;
    if (!raf) {
      raf = requestAnimationFrame(() => {
        raf = 0;
        if (acc) post('rotate', { delta: acc * 0.45 });
        acc = 0;
      });
    }
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      if (!$('modal').classList.contains('hidden')) return closeModal();
      if (!$('drawer').classList.contains('hidden')) return $('drawer').classList.add('hidden');
      if (state.open) closeUi();
      return;
    }
    if (!state.open || state.kind !== 'showroom' || !$('modal').classList.contains('hidden')) return;
    if (document.activeElement && document.activeElement.tagName === 'INPUT') return;
    if (e.key === 'ArrowRight') { e.preventDefault(); step(1); }
    else if (e.key === 'ArrowLeft') { e.preventDefault(); step(-1); }
  });

  window.addEventListener('message', (event) => {
    const d = event.data || {};
    if (d.type === 'open') openUi(d);
    else if (d.type === 'close') hideAll();
    else if (d.type === 'state') {
      const wasKind = state.kind;
      state = merge(d);
      if (state.open) {
        if (wasKind !== state.kind && state.kind === 'showroom') renderRail();
        render();
      }
    } else if (d.type === 'toast') {
      toast(d.message, d.level);
    }
  });
})();
