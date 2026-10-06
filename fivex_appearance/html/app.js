(() => {
  'use strict';

  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'fivex_appearance';

  // ── Icons ────────────────────────────────────────────────────────────
  const I = {
    identity: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    heritage: '<circle cx="7" cy="7" r="3"/><circle cx="17" cy="7" r="3"/><circle cx="12" cy="17" r="3"/><path d="M8.5 9.5 11 15M15.5 9.5 13 15"/>',
    face: '<circle cx="12" cy="12" r="9"/><path d="M9 10h.01M15 10h.01M9 15c1.5 1.5 4.5 1.5 6 0"/>',
    hair: '<path d="M4 14c0-6 3.5-10 8-10s8 4 8 10M4 14c2 0 4-2 4-5M20 14c-2 0-4-2-4-5M7 20c0-3 2-6 5-6s5 3 5 6"/>',
    overlays: '<path d="m12 3 1.9 4.6L18.5 9l-4.6 1.9L12 15.5l-1.9-4.6L5.5 9l4.6-1.4z"/><path d="M19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9z"/>',
    eyes: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    tattoos: '<path d="m12 19-7-7 3-3 7 7zM15 16l5-5-6-6-5 5M18 2l4 4"/>',
    outfits: '<path d="M6 2h12l1 6H5zM5 8v13h14V8M9 12h6"/>',
    male: '<circle cx="10" cy="14" r="6"/><path d="M14.5 9.5 21 3M15 3h6v6"/>',
    female: '<circle cx="12" cy="9" r="6"/><path d="M12 15v7M9 19h6"/>',
    left: '<path d="m15 18-6-6 6-6"/>',
    right: '<path d="m9 18 6-6-6-6"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    trash: '<path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/>',
    mask: '<path d="M4 6c3-1 5-1 8 1 3-2 5-2 8-1 1 6-1 11-4 12-2 1-3-2-4-2s-2 3-4 2c-3-1-5-6-4-12z"/>',
    top: '<path d="M20.4 6.6 16 3h-2a2 2 0 0 1-4 0H8L3.6 6.6a1 1 0 0 0 0 1.4l2.2 2.4L7 9.6V21h10V9.6l1.2.8 2.2-2.4a1 1 0 0 0 0-1.4z"/>',
    under: '<path d="M8 3h8l2 4v14H6V7z"/><path d="M9 3c0 2 1.5 3 3 3s3-1 3-3"/>',
    arms: '<path d="M7 3v8l-3 10M17 3v8l3 10M7 11h10"/>',
    pants: '<path d="M6 2h12l1 20h-5l-2-12-2 12H5z"/>',
    bag: '<path d="M6 7h12l1 14H5zM9 7V5a3 3 0 0 1 6 0v2"/>',
    shoe: '<path d="M3 17v-6l5-1 3 3 8 1a2 2 0 0 1 2 2v1H3zM3 20h18"/>',
    chain: '<path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.7 1.7M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.7-1.7"/>',
    vest: '<path d="M7 3 4 6v14h6v-6h4v6h6V6l-3-3-3 3h-4z"/>',
    decal: '<circle cx="12" cy="12" r="9"/><path d="m12 7 1.5 3.2 3.5.5-2.5 2.4.6 3.4L12 15l-3.1 1.5.6-3.4L7 10.7l3.5-.5z"/>',
    hat: '<path d="M2 15h20M4 15c0-5 3.6-9 8-9s8 4 8 9"/>',
    glasses: '<circle cx="6" cy="14" r="4"/><circle cx="18" cy="14" r="4"/><path d="M10 14h4M2 14l1-6M22 14l-1-6"/>',
    ear: '<path d="M6 8.5a6.5 6.5 0 1 1 13 0c0 6-6 6-6 10a3.5 3.5 0 1 1-7 0"/>',
    watch: '<circle cx="12" cy="12" r="6"/><path d="M12 9v3l1.5 1.5M9 3h6l1 3H8zM8 18l1 3h6l1-3"/>',
    bracelet: '<ellipse cx="12" cy="12" rx="9" ry="5"/><ellipse cx="12" cy="12" rx="5" ry="2.5"/>',
  };
  const ico = (n) => `<svg viewBox="0 0 24 24">${I[n] || I.top}</svg>`;

  // Store-style category order and icons
  const COMP_ORDER = [11, 8, 3, 4, 6, 1, 5, 7, 9, 10];
  const COMP_ICON = { 1: 'mask', 3: 'arms', 4: 'pants', 5: 'bag', 6: 'shoe', 7: 'chain', 8: 'under', 9: 'vest', 10: 'decal', 11: 'top' };
  const COMP_NAME = { 3: 'Arms', 7: 'Neck' };
  const PROP_ICON = { 0: 'hat', 1: 'glasses', 2: 'ear', 6: 'watch', 7: 'bracelet' };
  const PROP_IDS = [0, 1, 2, 6, 7];
  const BARBER_OVERLAYS = [1, 2, 4, 8];

  const FACE_GROUPS = [['Nose', [0, 1, 2, 3, 4, 5]], ['Eyebrows', [6, 7]], ['Cheeks', [8, 9, 10]], ['Eyes & lips', [11, 12]], ['Jaw', [13, 14]], ['Chin', [15, 16, 17, 18]], ['Neck', [19]]];
  const EYES = [['Green', '#3f8f4a'], ['Emerald', '#1f7a5c'], ['Light blue', '#6aa9d8'], ['Ocean blue', '#2a6fb0'], ['Light brown', '#9a6b3c'], ['Dark brown', '#5a3a1e'], ['Hazel', '#8a7340'], ['Dark gray', '#4a4f55'], ['Light gray', '#9aa2aa'], ['Pink', '#e07aa8'], ['Yellow', '#e0c040'], ['Purple', '#8048b0'], ['Blackout', '#0a0a0a'], ['Shades of gray', '#70757a'], ['Tequila sunrise', '#e88a30'], ['Atomic', '#40e070'], ['Warp', '#40a0ff'], ['ECola', '#d02020'], ['Space ranger', '#20c0e0'], ['Ying yang', '#c0c0c0'], ['Bullseye', '#e04040'], ['Lizard', '#a0c020'], ['Dragon', '#e06010'], ['Extra terrestrial', '#60e0a0'], ['Goat', '#c0a060'], ['Smiley', '#f0d000'], ['Possessed', '#f0f0f0'], ['Demon', '#ff3010'], ['Infected', '#b0c040'], ['Alien', '#50d050'], ['Undead', '#a0b0c0'], ['Zombie', '#c0d0a0']];
  const HAIR_HEX = ['#1c1c1c', '#1a1310', '#2a1a12', '#3b2416', '#4a2a14', '#5a3418', '#6c3e1c', '#7a4a20', '#8b5a24', '#9a6a2c', '#b07a34', '#c48a3c', '#d4a04c', '#e0b45c', '#c8c070', '#dcd8b0', '#8a3a28', '#a04030', '#b84828', '#d06030', '#6a2c14', '#4a1810', '#2c120c', '#5c4030', '#c4a078', '#dcc8a8', '#f0e0c8', '#fff4e0', '#b0b0b0', '#888888', '#5c5c5c', '#3a3a3a', '#6a2a6a', '#8a3a8a', '#4a1a4a', '#2a0a2a', '#1a3a6a', '#2a5a8a', '#3a7aaa', '#64b4d4', '#2a6a3a', '#3a8a4a', '#50a05c', '#78c878', '#8a1a1a', '#b02020', '#d03030', '#f05050', '#e8c040', '#f0d060', '#f8e080', '#fff0a0', '#d08040', '#e89850', '#f0b060', '#c06090', '#d070a0', '#e090b8', '#40c0c0', '#20a0a0', '#f4e4c4', '#c8b090', '#705030', '#403020'];
  const MAKEUP_HEX = ['#f2d6d0', '#e8b8b0', '#d49088', '#c07068', '#e07080', '#d04060', '#b02040', '#801028', '#f0a0c0', '#e070a8', '#c04088', '#901868', '#f0c070', '#e0a040', '#c08020', '#a06010', '#d0b090', '#b89070', '#987050', '#705040', '#c0c0c0', '#909090', '#606060', '#303030', '#80c0e0', '#5090c0', '#3070a0', '#184070', '#90e0c0', '#50c090', '#209060', '#106040', '#f0e0a0', '#e0c060', '#c0a030', '#908010', '#e8a090', '#d07060', '#b04030', '#801810', '#d0a0e0', '#a070c0', '#8040a0', '#501870', '#f8d8c8', '#e8c0a8', '#d0a088', '#b08068', '#704030', '#502818', '#301808', '#201000', '#ffb0b0', '#ff8080', '#e05050', '#c03030', '#a0d0ff', '#70b0f0', '#4080d0', '#2060b0', '#f0f0f0', '#d0d0d0', '#a0a0a0', '#707070'];

  const state = {
    open: false, mode: 'creator', group: null, cat: null, forced: false, hasLicense: true,
    appearance: null, outfits: [], locale: {}, config: {}, overlayMax: {}, enumCache: {},
    lastCamPreset: null, tatZone: 'all', tatQuery: '', outfitName: '', openAcc: {},
    dragging: false, lastX: 0, lastY: 0, previewTimer: null, pendingConfirm: null,
  };

  const $ = (id) => document.getElementById(id);
  const app = $('app');
  const dock = $('dock');
  const panel = $('panel');
  const catsEl = $('tabs');
  const groupsEl = $('groups');
  const modal = $('modal');

  const t = (key, fallback) => state.locale[key] || fallback || key;
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const at = (o, i) => (o ? (o[i] !== undefined ? o[i] : o[String(i)]) : undefined);
  const setAt = (o, i, v) => { o[String(i)] = v; };

  function post(name, data) {
    return fetch(`https://${resource}/${name}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({ ok: false }));
  }
  function toast(message, level) {
    if (!message) return;
    const el = document.createElement('div');
    el.className = `toast ${level || 'info'}`;
    el.textContent = message;
    $('toasts').appendChild(el);
    setTimeout(() => el.remove(), 3800);
  }
  function previewSoon() {
    clearTimeout(state.previewTimer);
    state.previewTimer = setTimeout(() => { state.previewTimer = null; post('preview', { appearance: state.appearance }); }, 30);
  }

  // ── Groups / categories per mode ─────────────────────────────────────
  const compName = (id) => COMP_NAME[id] || t('comp_' + id, 'Slot ' + id);
  const propName = (id) => t('prop_' + id, 'Prop ' + id);
  function groups() {
    const comps = COMP_ORDER.filter((id) => (state.config.clothingComponents || COMP_ORDER).includes(id));
    const props = state.config.propIds || PROP_IDS;
    const G = {
      character: { label: 'Character', cats: ['identity', 'heritage', 'face', 'hair', 'overlays', 'eyes'].map((id) => ({ key: 'tab:' + id, label: t('tab_' + id, id), icon: id })) },
      barber: { label: 'Barber', cats: ['hair', 'overlays', 'eyes'].map((id) => ({ key: 'tab:' + id, label: t('tab_' + id, id), icon: id })) },
      clothing: { label: 'Clothing', cats: comps.map((id) => ({ key: 'comp:' + id, label: compName(id), icon: COMP_ICON[id] })) },
      accessories: { label: 'Accessories', cats: props.map((id) => ({ key: 'prop:' + id, label: propName(id), icon: PROP_ICON[id] })) },
      tattoos: { label: 'Tattoos', cats: [{ key: 'tab:tattoos', label: 'Tattoos', icon: 'tattoos' }] },
      outfits: { label: 'Outfits', cats: [{ key: 'tab:outfits', label: 'Outfits', icon: 'outfits' }] },
    };
    const order = {
      creator: ['character', 'clothing', 'accessories', 'tattoos', 'outfits'],
      clothing: ['clothing', 'accessories', 'outfits'],
      barber: ['barber', 'outfits'],
      tattoo: ['tattoos', 'outfits'],
    }[state.mode] || ['clothing', 'accessories', 'outfits'];
    return order.map((k) => Object.assign({ id: k }, G[k]));
  }
  const currentCat = () => groups().flatMap((g) => g.cats).find((c) => c.key === state.cat) || null;

  function selectGroup(id) {
    const g = groups().find((x) => x.id === id) || groups()[0];
    state.group = g.id;
    state.cat = g.cats[0].key;
  }

  // ── Camera ───────────────────────────────────────────────────────────
  function camFor(key) {
    const [kind, raw] = key.split(':');
    const id = Number(raw);
    if (kind === 'comp') return id === 1 ? 'face' : (id === 4 || id === 6 ? 'legs' : (id === 5 ? 'full' : 'torso'));
    if (kind === 'prop') return id <= 2 ? 'face' : 'torso';
    if (raw === 'tattoos') return state.tatZone === 'head' ? 'face' : (/leg/.test(state.tatZone) ? 'legs' : (state.tatZone === 'all' ? 'full' : 'torso'));
    if (raw === 'outfits') return 'full';
    return 'face';
  }
  function setCamPreset(name, manual) {
    if (!name || (state.lastCamPreset === name && !manual)) return;
    state.lastCamPreset = name;
    document.querySelectorAll('[data-cam]').forEach((x) => x.classList.toggle('active', x.dataset.cam === name));
    post('camPreset', { name });
  }
  const syncCam = () => { if (state.open && state.cat) setCamPreset(camFor(state.cat), false); };

  // ── Enumerated items ─────────────────────────────────────────────────
  const enumKey = (kind, id) => (kind === 'prop' ? 'prop:' : 'component:') + id;
  function ensureEnum(kind, id, drawable) {
    const key = enumKey(kind, id);
    if (key in state.enumCache) return;
    state.enumCache[key] = null; // requested
    post('enumerate', { kind, id, drawable }).then((r) => {
      if (r && r.items) {
        state.enumCache[key] = r.items;
        if (state.open) render(true);
      }
    });
  }

  // ── Small builders ───────────────────────────────────────────────────
  function slider(id, label, value, min, max, step, opts) {
    opts = opts || {};
    const v = Number(value) || 0;
    const pct = ((v - min) / (max - min)) * 100;
    return `<div class="slider" data-slider="${id}"><div class="slider-top"><span>${esc(label)}</span><span class="v">${opts.percent ? Math.round(v * 100) + '%' : v.toFixed(2)}</span></div>
      <input type="range" class="${opts.center ? 'center' : ''}" min="${min}" max="${max}" step="${step}" value="${v}" style="--p:${pct}%" />
      ${opts.ends ? `<div class="slider-ends"><span>${esc(opts.ends[0])}</span><span>${esc(opts.ends[1])}</span></div>` : ''}</div>`;
  }
  function swatches(kind, selected, count, key) {
    const pal = kind === 'makeup' ? MAKEUP_HEX : HAIR_HEX;
    let h = '<div class="swatches">';
    for (let i = 0; i < Math.min(count || 64, 64); i++) h += `<button type="button" class="swatch${i === selected ? ' active' : ''}" data-swatch="${key}" data-i="${i}" style="background:${pal[i % pal.length]}" title="${i}"></button>`;
    return h + '</div>';
  }
  const sec = (title, meta, body) => `<div class="sec"><div class="sec-head"><span class="sec-title">${esc(title)}</span>${meta || ''}</div>${body}</div>`;

  /** Store grid: every valid item as a tile; selected one highlighted. kind: comp|prop|hair */
  function itemGrid(kind, slotId, current, allowNone) {
    const items = state.enumCache[enumKey(kind === 'prop' ? 'prop' : 'component', slotId)];
    if (!items) return `<div class="loading">Loading items…</div>`;
    let html = '<div class="items" data-grid="' + kind + ':' + slotId + '">';
    if (allowNone) html += `<button type="button" class="item${Number(current) < 0 ? ' active' : ''}" data-pick="-1">${ico('x')}<span class="sub">None</span></button>`;
    items.forEach((it, i) => {
      html += `<button type="button" class="item${Number(it.id) === Number(current) ? ' active' : ''}" data-pick="${it.id}"><span class="num">${i + 1}</span><span class="sub">#${it.id}</span></button>`;
    });
    return html + '</div>';
  }
  function variantRow(kind, slotId, drawable, current) {
    const items = state.enumCache[enumKey(kind === 'prop' ? 'prop' : 'component', slotId)];
    const it = items && items.find((x) => Number(x.id) === Number(drawable));
    const n = it ? Math.max(1, it.textures) : 1;
    let h = '<div class="variants">';
    for (let i = 0; i < Math.min(n, 64); i++) h += `<button type="button" class="variant${i === Number(current) ? ' active' : ''}" data-variant="${i}">${i + 1}</button>`;
    return h + '</div>';
  }
  function itemCount(kind, slotId) {
    const items = state.enumCache[enumKey(kind === 'prop' ? 'prop' : 'component', slotId)];
    return items ? items.length : 0;
  }
  const jumpBox = (n) => n ? `<label class="jump">Go to <input type="number" min="1" max="${n}" data-jump placeholder="#" /> of ${n}</label>` : '';

  // ── Category renderers ───────────────────────────────────────────────
  function renderComp(id) {
    const c = at(state.appearance.components, id) || { drawable: 0, texture: 0 };
    ensureEnum('component', id, c.drawable);
    const n = itemCount('comp', id);
    return sec('Variant', '', variantRow('comp', id, c.drawable, c.texture))
      + sec(compName(id), jumpBox(n), itemGrid('comp', id, c.drawable, false));
  }
  function renderProp(id) {
    const p = at(state.appearance.props, id) || { drawable: -1, texture: 0 };
    ensureEnum('prop', id, p.drawable);
    const n = itemCount('prop', id);
    return (Number(p.drawable) >= 0 ? sec('Variant', '', variantRow('prop', id, p.drawable, p.texture)) : '')
      + sec(propName(id), jumpBox(n), itemGrid('prop', id, p.drawable, true));
  }
  function renderIdentity() {
    const male = state.appearance.model === 'mp_m_freemode_01';
    return `<p class="lead">${esc(t('sex_hint', ''))}</p><div class="choices">
      <button type="button" class="choice${male ? ' active' : ''}" data-sex="mp_m_freemode_01">${ico('male')}${esc(t('sex_male', 'Male'))}</button>
      <button type="button" class="choice${!male ? ' active' : ''}" data-sex="mp_f_freemode_01">${ico('female')}${esc(t('sex_female', 'Female'))}</button></div>`;
  }
  const parentName = (id) => { const p = (state.config.parents || []).find((x) => Number(x.id) === Number(id)); return p ? p.name : '#' + id; };
  const parentRow = (key, who) => `<div class="pick-row" data-parent="${key}"><span class="who">${who}</span>
      <button type="button" class="arrow" data-pdir="-1">${ico('left')}</button><span class="name">${esc(parentName(state.appearance.headBlend[key]))}<small>#${state.appearance.headBlend[key]}</small></span>
      <button type="button" class="arrow" data-pdir="1">${ico('right')}</button></div>`;
  function renderHeritage() {
    const hb = state.appearance.headBlend;
    return sec('Face shape', '', parentRow('shapeFirst', 'Parent A') + parentRow('shapeSecond', 'Parent B') + parentRow('shapeThird', 'Parent C')
        + slider('hb:shapeMix', t('mix_shape', 'Shape mix'), hb.shapeMix, 0, 1, 0.01, { percent: true, ends: ['Parent A', 'Parent B'] })
        + slider('hb:thirdMix', t('mix_third', 'Third mix'), hb.thirdMix, 0, 1, 0.01, { percent: true, ends: ['None', 'Parent C'] }))
      + sec('Skin tone', '', parentRow('skinFirst', 'Parent A') + parentRow('skinSecond', 'Parent B') + parentRow('skinThird', 'Parent C')
        + slider('hb:skinMix', t('mix_skin', 'Skin mix'), hb.skinMix, 0, 1, 0.01, { percent: true, ends: ['Parent A', 'Parent B'] }));
  }
  function renderFace() {
    return FACE_GROUPS.map(([name, ids], gi) => {
      const k = 'face' + gi;
      const open = state.openAcc[k] ?? gi === 0;
      const changed = ids.some((i) => Math.abs(Number(at(state.appearance.faceFeatures, i) || 0)) > 0.001);
      return `<div class="acc${open ? ' open' : ''}" data-acc="${k}"><div class="acc-head"><button type="button" class="t" data-acc-toggle="${k}">${esc(name)}</button>
        ${changed ? `<button type="button" class="link" data-face-reset="${ids.join(',')}">Reset</button>` : ''}<span class="chev">${ico('right')}</span></div>
        <div class="acc-body">${ids.map((i) => slider('ff:' + i, t('face_' + i, 'Feature ' + i), at(state.appearance.faceFeatures, i) || 0, -1, 1, 0.01, { center: true })).join('')}</div></div>`;
    }).join('');
  }
  function renderHair() {
    const h = state.appearance.hair;
    ensureEnum('component', 2, h.style);
    const pal = state.config.palettes || { hair: 64 };
    return sec('Colour', `<span class="sec-meta">#${h.color}</span>`, swatches('hair', h.color, pal.hair, 'hair.color'))
      + sec('Highlight', `<span class="sec-meta">#${h.highlight}</span>`, swatches('hair', h.highlight, pal.hair, 'hair.highlight'))
      + sec('Variant', '', variantRow('hair', 2, h.style, h.texture))
      + sec(t('hair_style', 'Hairstyle'), jumpBox(itemCount('hair', 2)), itemGrid('hair', 2, h.style, false));
  }
  function renderOverlays() {
    const pal = state.config.palettes || { hair: 64, makeup: 64 };
    const ids = state.mode === 'barber' ? BARBER_OVERLAYS : Array.from({ length: 13 }, (_, i) => i);
    const metaList = state.config.overlays || [];
    return ids.map((id) => {
      const ov = at(state.appearance.overlays, id) || { index: 255, opacity: 0, colourType: 0, colour: 0 };
      const meta = metaList.find((m) => Number(m.id) === id) || {};
      const max = Number(at(state.overlayMax, id) || 0);
      const on = ov.index < 255 && ov.opacity > 0;
      const ct = Number(meta.colourType || ov.colourType || 0);
      const open = on && (state.openAcc['ov' + id] ?? true);
      let styles = '';
      for (let i = 0; i < max; i++) styles += `<button type="button" class="variant${on && ov.index === i ? ' active' : ''}" data-ovstyle="${id}" data-i="${i}">${i + 1}</button>`;
      return `<div class="acc${open ? ' open' : ''}" data-acc="ov${id}"><div class="acc-head"><button type="button" class="t" data-acc-toggle="ov${id}">${esc(t('overlay_' + id, 'Overlay ' + id))}
          <span class="s">${on ? `Style ${ov.index + 1} · ${Math.round(ov.opacity * 100)}%` : 'Off'}</span></button>
          <button type="button" class="switch${on ? ' on' : ''}" data-ovtoggle="${id}" aria-label="Toggle"></button></div>
        ${on ? `<div class="acc-body">${sec('Style', `<span class="sec-meta">${max} styles</span>`, `<div class="variants">${styles}</div>`)}
          ${slider('ov.' + id + '.opacity', t('overlay_opacity', 'Opacity'), ov.opacity || 0, 0, 1, 0.01, { percent: true })}
          ${ct === 1 ? sec('Colour', '', swatches('hair', ov.colour || 0, pal.hair, 'ov.' + id + '.colour')) : ''}
          ${ct === 2 ? sec('Colour', '', swatches('makeup', ov.colour || 0, pal.makeup, 'ov.' + id + '.colour')) : ''}</div>` : ''}</div>`;
    }).join('');
  }
  function renderEyes() {
    const n = (state.config.palettes && state.config.palettes.eyes) || 32;
    return `<div class="eyes">${EYES.slice(0, n).map(([name, color], i) => `<button type="button" class="eye${state.appearance.eyeColor === i ? ' active' : ''}" data-eye="${i}"><i style="background:${color}"></i>${esc(name)}</button>`).join('')}</div>`;
  }
  const tattooOn = (rec) => (state.appearance.tattoos || []).some((x) => x.collection === rec.collection && x.overlay === rec.overlay);
  function tattooRows() {
    const sex = state.appearance.model === 'mp_f_freemode_01' ? 'f' : 'm';
    const q = state.tatQuery.trim().toLowerCase();
    return (state.config.tattoos || []).filter((r) => (!r.sex || r.sex === 'any' || r.sex === sex) && (state.tatZone === 'all' || r.zone === state.tatZone) && (!q || String(r.label || r.overlay).toLowerCase().includes(q)));
  }
  function tattooListHtml() {
    const rows = tattooRows();
    if (!rows.length) return `<div class="empty">No tattoos here.</div>`;
    return `<div class="list">${rows.map((r) => `<button type="button" class="li${tattooOn(r) ? ' on' : ''}" data-tat="${r.id}"><span class="box">${ico('check')}</span>
      <span class="grow"><div class="nm">${esc(r.label || r.overlay)}</div><div class="sb">${esc(t('zone_' + r.zone, r.zone))}</div></span></button>`).join('')}</div>`;
  }
  function renderTattoos() {
    const zones = ['all'].concat(state.config.zones || ['head', 'torso', 'left_arm', 'right_arm', 'left_leg', 'right_leg']);
    const applied = state.appearance.tattoos || [];
    const count = (z) => applied.filter((x) => z === 'all' || x.zone === z).length;
    return `<div class="chips" style="margin-bottom:10px">${zones.map((z) => `<button type="button" class="chip${state.tatZone === z ? ' active' : ''}" data-zone="${z}">${esc(t('zone_' + z, z))}${count(z) ? `<span class="n">${count(z)}</span>` : ''}</button>`).join('')}</div>
      <div class="row" style="margin-bottom:10px"><div class="search">${ico('search')}<input class="input" id="tat-q" placeholder="Search tattoos" value="${esc(state.tatQuery)}" /></div>
        ${count(state.tatZone) ? `<button type="button" class="btn sm danger" id="btn-clear-zone">${esc(state.tatZone === 'all' ? t('btn_clear_all', 'Clear all') : t('btn_clear_zone', 'Clear zone'))}</button>` : ''}</div>
      <div id="tat-list">${tattooListHtml()}</div>`;
  }
  function renderOutfits() {
    const list = state.outfits || [];
    return sec('Save current look', `<span class="sec-meta">${list.length} / ${state.config.maxOutfits || 16}</span>`,
      `<div class="row"><input class="input" id="outfit-name" maxlength="${state.config.maxOutfitName || 24}" value="${esc(state.outfitName)}" placeholder="${esc(t('outfit_name', 'Outfit name'))}" />
        <button type="button" class="btn primary sm" style="height:36px" id="btn-outfit-save">Save</button></div>`)
      + sec('My outfits', '', list.length ? `<div class="list">${list.map((o, i) => `<div class="li">${ico('outfits')}<span class="grow"><div class="nm">${esc(o.name)}</div></span>
          <button type="button" class="btn sm" data-oload="${i + 1}">Wear</button><button type="button" class="btn sm danger" data-odel="${i + 1}" title="Delete">${ico('trash')}</button></div>`).join('')}</div>`
        : `<div class="empty">${esc(t('outfit_empty', 'No saved outfits.'))}</div>`);
  }

  function renderCat() {
    const [kind, raw] = state.cat.split(':');
    if (kind === 'comp') return renderComp(Number(raw));
    if (kind === 'prop') return renderProp(Number(raw));
    return ({ identity: renderIdentity, heritage: renderHeritage, face: renderFace, hair: renderHair, overlays: renderOverlays, eyes: renderEyes, tattoos: renderTattoos, outfits: renderOutfits }[raw] || renderIdentity)();
  }

  function render(keepScroll) {
    const top = panel.scrollTop;
    const gs = groups();
    if (!gs.find((g) => g.id === state.group)) selectGroup(gs[0].id);
    const g = gs.find((x) => x.id === state.group);
    if (!g.cats.find((c) => c.key === state.cat)) state.cat = g.cats[0].key;
    groupsEl.innerHTML = gs.map((x) => `<button type="button" class="group${x.id === state.group ? ' active' : ''}" data-group="${x.id}">${esc(x.label)}</button>`).join('');
    catsEl.innerHTML = g.cats.length > 1 ? g.cats.map((c) => `<button type="button" class="cat${c.key === state.cat ? ' active' : ''}" data-cat="${c.key}" title="${esc(c.label)}">${ico(c.icon)}<span>${esc(c.label)}</span></button>`).join('') : '';
    const cat = currentCat();
    $('tab-title').textContent = cat ? cat.label : '';
    $('brand-sub').textContent = { creator: 'Character creator', clothing: 'Clothing store', barber: 'Barber shop', tattoo: 'Tattoo parlour' }[state.mode] || t('mode_' + state.mode, state.mode);
    const banner = $('banner');
    if (!state.hasLicense) { banner.className = 'banner warn'; banner.textContent = t('no_license_banner', 'Session preview only.'); }
    else if (state.forced) { banner.className = 'banner'; banner.textContent = t('first_join_hint', 'You must save before you can leave.'); }
    else banner.className = 'banner hidden';
    $('btn-esc').disabled = !!state.forced;
    panel.innerHTML = renderCat();
    if (keepScroll) panel.scrollTop = top;
  }

  // ── Applying changes ─────────────────────────────────────────────────
  function setDrawable(kind, id, drawable) {
    const a = state.appearance;
    if (kind === 'hair') {
      a.hair.style = drawable; a.hair.texture = 0;
      setAt(a.components, 2, { drawable, texture: 0 });
      post('textures', { kind: 'component', id: 2, drawable }).then(() => previewSoon());
    } else {
      const store = kind === 'comp' ? a.components : a.props;
      const cur = at(store, id) || { drawable: 0, texture: 0 };
      cur.drawable = drawable; cur.texture = 0;
      setAt(store, id, cur);
    }
    previewSoon();
    render(true);
  }
  function setVariant(kind, id, texture) {
    const a = state.appearance;
    if (kind === 'hair') { a.hair.texture = texture; setAt(a.components, 2, { drawable: a.hair.style, texture }); }
    else {
      const store = kind === 'comp' ? a.components : a.props;
      const cur = at(store, id) || { drawable: 0, texture: 0 };
      cur.texture = texture; setAt(store, id, cur);
    }
    previewSoon();
    render(true);
  }
  function gridContext() {
    const [kind, raw] = state.cat.split(':');
    if (kind === 'comp') { const c = at(state.appearance.components, raw) || {}; return { kind: 'comp', id: Number(raw), drawable: c.drawable, texture: c.texture, none: false }; }
    if (kind === 'prop') { const p = at(state.appearance.props, raw) || {}; return { kind: 'prop', id: Number(raw), drawable: p.drawable, texture: p.texture, none: true }; }
    if (raw === 'hair') return { kind: 'hair', id: 2, drawable: state.appearance.hair.style, texture: state.appearance.hair.texture, none: false };
    return null;
  }
  function stepItem(dir) {
    const g = gridContext();
    if (!g) return;
    const items = state.enumCache[enumKey(g.kind === 'prop' ? 'prop' : 'component', g.id)];
    if (!items || !items.length) return;
    const ids = (g.none ? [-1] : []).concat(items.map((x) => Number(x.id)));
    const i = ids.indexOf(Number(g.drawable));
    setDrawable(g.kind, g.id, ids[(i + dir + ids.length) % ids.length]);
    const act = panel.querySelector('.items .item.active');
    if (act) act.scrollIntoView({ block: 'nearest' });
  }
  function stepVariant(dir) {
    const g = gridContext();
    if (!g || Number(g.drawable) < 0) return;
    const items = state.enumCache[enumKey(g.kind === 'prop' ? 'prop' : 'component', g.id)];
    const it = items && items.find((x) => Number(x.id) === Number(g.drawable));
    const n = it ? Math.max(1, it.textures) : 1;
    setVariant(g.kind, g.id, (Number(g.texture) + dir + n) % n);
  }
  function stepParent(key, dir) {
    const parents = (state.config.parents || []).map((p) => Number(p.id));
    const list = parents.length ? parents : Array.from({ length: (state.config.maxParent || 45) + 1 }, (_, i) => i);
    const idx = (list.indexOf(Number(state.appearance.headBlend[key])) + dir + list.length) % list.length;
    state.appearance.headBlend[key] = list[idx];
    previewSoon(); render(true);
  }

  // ── Events ───────────────────────────────────────────────────────────
  groupsEl.addEventListener('click', (e) => {
    const b = e.target.closest('[data-group]');
    if (!b) return;
    selectGroup(b.dataset.group);
    panel.scrollTop = 0; syncCam(); render();
  });
  catsEl.addEventListener('click', (e) => {
    const b = e.target.closest('[data-cat]');
    if (!b) return;
    state.cat = b.dataset.cat;
    panel.scrollTop = 0; syncCam(); render();
  });
  $('cam-row').addEventListener('click', (e) => {
    const b = e.target.closest('[data-cam]');
    if (b) setCamPreset(b.dataset.cam, true);
    if (e.target.closest('#cam-flip')) post('camFlip', {});
  });
  $('btn-esc').addEventListener('click', () => { if (!state.forced) post('close', {}); });
  $('btn-save').addEventListener('click', () => post('save', { appearance: state.appearance }));
  $('btn-reset').addEventListener('click', () => post('reset', {}).then((r) => { if (r && r.appearance) { state.appearance = r.appearance; state.enumCache = {}; render(true); } }));
  $('btn-rand').addEventListener('click', () => {
    const [kind, raw] = state.cat.split(':');
    const tab = kind === 'comp' ? 'clothing' : (kind === 'prop' ? 'props' : raw);
    post('randomize', { tab, all: state.mode === 'creator' && raw === 'identity' }).then((r) => {
      if (r && r.appearance) { state.appearance = r.appearance; state.enumCache = {}; render(true); }
    });
  });

  panel.addEventListener('click', (e) => {
    const q = (s) => e.target.closest(s);
    let el;
    if ((el = q('[data-pick]'))) { const g = gridContext(); if (g) setDrawable(g.kind, g.id, Number(el.dataset.pick)); return; }
    if ((el = q('[data-variant]'))) { const g = gridContext(); if (g) setVariant(g.kind, g.id, Number(el.dataset.variant)); return; }
    if ((el = q('[data-sex]'))) {
      post('setSex', { model: el.dataset.sex }).then((r) => { if (r && r.appearance) { state.appearance = r.appearance; state.enumCache = {}; render(true); } });
      return;
    }
    if ((el = q('[data-pdir]'))) { stepParent(el.closest('[data-parent]').dataset.parent, Number(el.dataset.pdir)); return; }
    if ((el = q('[data-face-reset]'))) {
      el.dataset.faceReset.split(',').forEach((i) => setAt(state.appearance.faceFeatures, Number(i), 0));
      previewSoon(); render(true); return;
    }
    if ((el = q('[data-acc-toggle]'))) {
      const acc = el.closest('[data-acc]');
      const open = !acc.classList.contains('open');
      state.openAcc[el.dataset.accToggle] = open;
      acc.classList.toggle('open', open);
      return;
    }
    if ((el = q('[data-swatch]'))) {
      const key = el.dataset.swatch;
      const i = Number(el.dataset.i);
      if (key === 'hair.color') state.appearance.hair.color = i;
      else if (key === 'hair.highlight') state.appearance.hair.highlight = i;
      else if (key.startsWith('ov.')) { const oid = Number(key.split('.')[1]); const ov = at(state.appearance.overlays, oid); if (ov) { ov.colour = i; setAt(state.appearance.overlays, oid, ov); } }
      el.parentElement.querySelectorAll('.swatch').forEach((s) => s.classList.toggle('active', s === el));
      const meta = el.closest('.sec') && el.closest('.sec').querySelector('.sec-meta');
      if (meta && key.startsWith('hair.')) meta.textContent = '#' + i;
      previewSoon(); return;
    }
    if ((el = q('[data-eye]'))) {
      state.appearance.eyeColor = Number(el.dataset.eye);
      panel.querySelectorAll('[data-eye]').forEach((s) => s.classList.toggle('active', s === el));
      previewSoon(); return;
    }
    if ((el = q('[data-ovtoggle]'))) {
      const id = Number(el.dataset.ovtoggle);
      const ov = at(state.appearance.overlays, id) || { index: 255, opacity: 0, colourType: 0, colour: 0, secondColour: 0 };
      const on = ov.index < 255 && ov.opacity > 0;
      if (on) { ov.index = 255; ov.opacity = 0; } else { ov.index = 0; ov.opacity = 1; state.openAcc['ov' + id] = true; }
      setAt(state.appearance.overlays, id, ov);
      previewSoon(); render(true); return;
    }
    if ((el = q('[data-ovstyle]'))) {
      const id = Number(el.dataset.ovstyle);
      const ov = at(state.appearance.overlays, id);
      if (ov) { ov.index = Number(el.dataset.i); if (ov.opacity <= 0) ov.opacity = 1; setAt(state.appearance.overlays, id, ov); }
      previewSoon(); render(true); return;
    }
    if ((el = q('[data-zone]'))) { state.tatZone = el.dataset.zone; syncCam(); render(true); return; }
    if ((el = q('[data-tat]'))) {
      const rec = (state.config.tattoos || []).find((x) => Number(x.id) === Number(el.dataset.tat));
      if (!rec) return;
      const list = state.appearance.tattoos || [];
      const idx = list.findIndex((x) => x.collection === rec.collection && x.overlay === rec.overlay);
      if (idx >= 0) list.splice(idx, 1); else list.push({ collection: rec.collection, overlay: rec.overlay, zone: rec.zone });
      state.appearance.tattoos = list;
      previewSoon(); render(true); return;
    }
    if (q('#btn-clear-zone')) {
      const z = state.tatZone;
      state.appearance.tattoos = z === 'all' ? [] : (state.appearance.tattoos || []).filter((x) => x.zone !== z);
      previewSoon(); render(true); return;
    }
    if (q('#btn-outfit-save')) {
      const name = ($('outfit-name').value || '').trim();
      state.outfitName = name;
      if (!name) { toast(t('outfit_named', 'Enter a name'), 'error'); return; }
      const go = () => post('outfitSave', { name, appearance: state.appearance });
      if ((state.outfits || []).some((o) => o.name === name)) confirmModal(t('btn_save_outfit', 'Save outfit'), t('outfit_confirm_overwrite', 'Overwrite?'), go);
      else go();
      return;
    }
    if ((el = q('[data-oload]'))) { const id = Number(el.dataset.oload); confirmModal('Wear outfit', t('outfit_confirm_load', 'Load and save as current?'), () => post('outfitLoad', { id })); return; }
    if ((el = q('[data-odel]'))) { const id = Number(el.dataset.odel); confirmModal(t('btn_delete', 'Delete'), t('outfit_confirm_delete', 'Delete this outfit?'), () => post('outfitDelete', { id })); }
  });

  panel.addEventListener('input', (e) => {
    const el = e.target;
    if (el.id === 'outfit-name') { state.outfitName = el.value; return; }
    if (el.id === 'tat-q') { state.tatQuery = el.value; $('tat-list').innerHTML = tattooListHtml(); return; }
    const sl = el.closest('[data-slider]');
    if (!sl) return;
    const id = sl.dataset.slider;
    const v = Number(el.value);
    el.style.setProperty('--p', `${((v - Number(el.min)) / (Number(el.max) - Number(el.min))) * 100}%`);
    const vEl = sl.querySelector('.v');
    if (vEl) vEl.textContent = (id.startsWith('hb:') || id.endsWith('.opacity')) ? `${Math.round(v * 100)}%` : v.toFixed(2);
    if (id.startsWith('hb:')) state.appearance.headBlend[id.slice(3)] = v;
    else if (id.startsWith('ff:')) setAt(state.appearance.faceFeatures, Number(id.slice(3)), v);
    else if (id.startsWith('ov.')) {
      const oid = Number(id.split('.')[1]);
      const ov = at(state.appearance.overlays, oid);
      if (ov) { ov.opacity = v; if (v > 0 && ov.index >= 255) ov.index = 0; setAt(state.appearance.overlays, oid, ov); }
    }
    previewSoon();
  });
  panel.addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' || !e.target.matches('[data-jump]')) return;
    const g = gridContext();
    const items = g && state.enumCache[enumKey(g.kind === 'prop' ? 'prop' : 'component', g.id)];
    const n = Number(e.target.value);
    if (!items || !(n >= 1 && n <= items.length)) { toast(`Pick 1 to ${items ? items.length : 0}`, 'error'); return; }
    setDrawable(g.kind, g.id, Number(items[n - 1].id));
    const act = panel.querySelector('.items .item.active');
    if (act) act.scrollIntoView({ block: 'center' });
  });

  function confirmModal(title, body, onOk) {
    $('modal-title').textContent = title;
    $('modal-body').textContent = body;
    state.pendingConfirm = onOk;
    modal.classList.remove('hidden');
  }
  $('modal-form').addEventListener('submit', (e) => {
    e.preventDefault();
    modal.classList.add('hidden');
    const fn = state.pendingConfirm; state.pendingConfirm = null;
    if (fn) fn();
  });
  $('modal-cancel').addEventListener('click', () => { modal.classList.add('hidden'); state.pendingConfirm = null; });

  // ── Camera input outside the panel ───────────────────────────────────
  const overUi = (el) => el.closest('#dock') || el.closest('#modal') || el.closest('#cam-row');
  dock.addEventListener('mouseenter', () => post('setHover', { hover: true }));
  dock.addEventListener('mouseleave', () => post('setHover', { hover: false }));
  window.addEventListener('mousedown', (e) => {
    if (!state.open || overUi(e.target)) return;
    state.dragging = true; state.lastX = e.clientX; state.lastY = e.clientY;
    document.body.style.cursor = 'grabbing';
  });
  window.addEventListener('mouseup', () => { state.dragging = false; document.body.style.cursor = ''; });
  window.addEventListener('mousemove', (e) => {
    if (!state.open || !state.dragging) return;
    const dx = e.clientX - state.lastX; const dy = e.clientY - state.lastY;
    state.lastX = e.clientX; state.lastY = e.clientY;
    post('camDrag', { dx, dy });
  });
  window.addEventListener('wheel', (e) => { if (state.open && !overUi(e.target)) post('camZoom', { delta: e.deltaY }); }, { passive: true });
  window.addEventListener('keydown', (e) => {
    if (!state.open) return;
    const typing = /^(input|textarea)$/i.test((e.target && e.target.tagName) || '');
    if (e.key === 'Escape') {
      e.preventDefault();
      if (!modal.classList.contains('hidden')) { modal.classList.add('hidden'); state.pendingConfirm = null; return; }
      if (!state.forced) post('close', {});
      return;
    }
    if (typing) return;
    if (e.code === 'Space') { e.preventDefault(); post('camFlip', {}); return; }
    // arrows browse items (left/right) and variants (up/down) in store grids
    if (e.key === 'ArrowRight') { e.preventDefault(); stepItem(1); }
    if (e.key === 'ArrowLeft') { e.preventDefault(); stepItem(-1); }
    if (e.key === 'ArrowUp') { e.preventDefault(); stepVariant(1); }
    if (e.key === 'ArrowDown') { e.preventDefault(); stepVariant(-1); }
  });

  // ── Messages from Lua ────────────────────────────────────────────────
  window.addEventListener('message', (event) => {
    const d = event.data || {};
    if (d.type === 'open') {
      state.open = true;
      state.mode = d.mode || 'creator';
      state.forced = !!d.forced;
      state.hasLicense = d.hasLicense !== false;
      state.appearance = d.appearance;
      state.outfits = d.outfits || [];
      state.locale = d.locale || {};
      state.config = d.config || {};
      state.overlayMax = d.overlayMax || {};
      state.enumCache = {};
      state.openAcc = {};
      state.outfitName = '';
      state.tatQuery = '';
      state.tatZone = 'all';
      state.lastCamPreset = null;
      selectGroup(groups()[0].id);
      app.classList.remove('hidden');
      panel.scrollTop = 0;
      syncCam();
      render();
    } else if (d.type === 'close') {
      state.open = false; state.dragging = false;
      app.classList.add('hidden'); modal.classList.add('hidden');
    } else if (d.type === 'toast') {
      toast(d.message, d.level);
    } else if (d.type === 'outfits') {
      state.outfits = d.outfits || [];
      if (state.open && state.cat === 'tab:outfits') render(true);
    } else if (d.type === 'appearance' || d.type === 'saved') {
      if (d.appearance) state.appearance = d.appearance;
      if (d.outfits) state.outfits = d.outfits;
      state.enumCache = {};
      if (state.open) render(true);
    }
  });
})();
