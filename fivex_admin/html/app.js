(() => {
  'use strict';

  const resource = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'fivex_admin';

  // ── Icons (24px stroke) ────────────────────────────────────────────────
  const I = {
    users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
    ban: '<circle cx="12" cy="12" r="9"/><path d="m5.6 5.6 12.8 12.8"/>',
    log: '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M8 13h8M8 17h5"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    car: '<path d="M5 17h14M5 17a2 2 0 1 1-4 0v-5l2.5-5h13L19 12v5a2 2 0 1 1-4 0"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/><path d="M3 12h18"/>',
    gun: '<path d="M2 9h17l2 3h-6l-1 3h-3l-1 4H6l1-4-5-2z"/>',
    box: '<path d="M21 8 12 3 3 8v8l9 5 9-5z"/><path d="m3 8 9 5 9-5M12 13v8"/>',
    pin: '<path d="M12 22s7-6.2 7-12a7 7 0 0 0-14 0c0 5.8 7 12 7 12z"/><circle cx="12" cy="10" r="2.5"/>',
    globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
    code: '<path d="m8 6-6 6 6 6M16 6l6 6-6 6"/>',
    shield: '<path d="M12 2 4 5v6c0 5 3.4 9.4 8 11 4.6-1.6 8-6 8-11V5l-8-3z"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    refresh: '<path d="M21 12a9 9 0 1 1-2.6-6.4L21 8"/><path d="M21 3v5h-5"/>',
    copy: '<rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h10"/>',
    eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    eyeOff: '<path d="M17.9 17.9A10 10 0 0 1 12 19c-6.4 0-10-7-10-7a18 18 0 0 1 5-5.9M9.9 4.2A9 9 0 0 1 12 4c6.4 0 10 7 10 7a18 18 0 0 1-2.2 3.2M1 1l22 22"/>',
    send: '<path d="m22 2-7 20-4-9-9-4z"/><path d="M22 2 11 13"/>',
    arrowIn: '<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4M10 17l5-5-5-5M15 12H3"/>',
    arrowOut: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>',
    snow: '<path d="M12 2v20M4.9 4.9l14.2 14.2M2 12h20M4.9 19.1 19.1 4.9"/>',
    heart: '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8z"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    vest: '<path d="M7 3 4 6v14h6v-6h4v6h6V6l-3-3-3 3h-4z"/>',
    zap: '<path d="M13 2 3 14h9l-1 8 10-12h-9z"/>',
    mic: '<rect x="9" y="2" width="6" height="12" rx="3"/><path d="M19 10a7 7 0 0 1-14 0M12 17v5"/>',
    micOff: '<path d="M1 1l22 22M9 9v3a3 3 0 0 0 5.1 2.1M15 9.3V5a3 3 0 0 0-5.9-.6M17 16.9A7 7 0 0 1 5 12v-2m14 0v2c0 .8-.1 1.5-.4 2.2M12 19v3"/>',
    camera: '<path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/>',
    alert: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/>',
    kick: '<path d="M18 6 6 18M6 6l12 12"/>',
    msg: '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
    layers: '<path d="m12 2 10 5-10 5L2 7z"/><path d="m2 17 10 5 10-5M2 12l10 5 10-5"/>',
    wrench: '<path d="M14.7 6.3a4 4 0 0 0 5 5L22 14l-8 8-2.3-2.3a4 4 0 0 0-5-5L2 10l8-8z"/>',
    droplet: '<path d="M12 2.7 6.3 8.3a8 8 0 1 0 11.4 0z"/>',
    rotate: '<path d="M1 4v6h6"/><path d="M3.5 15a9 9 0 1 0 2.1-9.4L1 10"/>',
    power: '<path d="M18.4 6.6a9 9 0 1 1-12.8 0M12 2v10"/>',
    rocket: '<path d="M4.5 16.5c-1.5 1.3-2 5-2 5s3.7-.5 5-2c.7-.8.7-2.1-.1-2.9a2.2 2.2 0 0 0-2.9-.1zM12 15l-3-3a22 22 0 0 1 2-4A13 13 0 0 1 22 2c0 2.7-.8 7.5-6 11a22 22 0 0 1-4 2z"/><path d="M9 12H4s.6-3 2-4c1.6-1.1 5 0 5 0M12 15v5s3-.6 4-2c1.1-1.6 0-5 0-5"/>',
    seat: '<path d="M5 21v-4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v4M7 15V5a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v10"/>',
    trash: '<path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/>',
    save: '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><path d="M17 21v-8H7v8M7 3v5h8"/>',
    flag: '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1zM4 22v-7"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    cloud: '<path d="M18 10h-1.3A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z"/>',
    rain: '<path d="M16 13V21M8 13v8M12 15v8"/><path d="M20 16.6A5 5 0 0 0 18 7h-1.3A8 8 0 1 0 4 15.3"/>',
    bolt: '<path d="M19 16.9A5 5 0 0 0 18 7h-1.3A8 8 0 1 0 4 15.3"/><path d="m13 11-4 6h6l-4 6"/>',
    fog: '<path d="M4 14h16M4 18h16M6 10h12"/><path d="M8 6h8"/>',
    moon: '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
    pumpkin: '<path d="M12 6c-5 0-8 3-8 7s3 7 8 7 8-3 8-7-3-7-8-7z"/><path d="M12 6V3M9 7c-1.5 2-1.5 10 0 12M15 7c1.5 2 1.5 10 0 12"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/>',
    bulb: '<path d="M9 18h6M10 22h4M12 2a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2z"/>',
    broom: '<path d="M14 4 20 10M3 21l7-7M10 14l-3 7 7-3 6-6-4-4z"/>',
    star: '<path d="m12 2 3.1 6.3 6.9 1-5 4.9 1.2 6.8L12 17.8 5.8 21l1.2-6.8-5-4.9 6.9-1z"/>',
    jump: '<path d="M12 19V5M5 12l7-7 7 7"/>',
    run: '<circle cx="14" cy="4" r="2"/><path d="m6 22 4-8 3 3v5M9 9l3-2 3 3 3 1M10 14l-3-3"/>',
    wind: '<path d="M9.6 4.6A2 2 0 1 1 11 8H2M12.6 19.4A2 2 0 1 0 14 16H2M17.5 8A2.5 2.5 0 1 1 19.5 12H2"/>',
    ghost: '<path d="M9 10h.01M15 10h.01M12 2a8 8 0 0 0-8 8v12l3-3 2.5 2.5L12 19l2.5 2.5L17 19l3 3V10a8 8 0 0 0-8-8z"/>',
    plane: '<path d="M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.3c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.2z"/>',
    tag: '<path d="M20.6 13.4 13.4 20.6a2 2 0 0 1-2.8 0L2 12V2h10l8.6 8.6a2 2 0 0 1 0 2.8z"/><circle cx="7" cy="7" r="1.5"/>',
    hash: '<path d="M4 9h16M4 15h16M10 3 8 21M16 3l-2 18"/>',
    terminal: '<path d="m4 17 6-6-6-6M12 19h8"/>',
    megaphone: '<path d="M3 11v3a1 1 0 0 0 1 1h3l6 5V5L7 10H4a1 1 0 0 0-1 1zM17 8a5 5 0 0 1 0 8"/>',
    door: '<path d="M3 21h18M5 21V4a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v17"/><path d="M15 12h.01"/>',
    lock: '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    stop: '<rect x="5" y="5" width="14" height="14" rx="2"/>',
    vector: '<path d="M12 2v20M2 12h20"/><circle cx="12" cy="12" r="3"/>',
    compass: '<circle cx="12" cy="12" r="9"/><path d="m16 8-2 6-6 2 2-6z"/>',
  };
  const ico = (name) => `<svg viewBox="0 0 24 24">${I[name] || I.zap}</svg>`;

  // Sidebar sections (order + grouping). A section only shows when the user has an action in it.
  const SECTIONS = [
    { group: 'Moderation', items: [
      { id: 'players', label: 'Players', icon: 'users', sub: 'Inspect and manage everyone online' },
      { id: 'bans', label: 'Bans', icon: 'ban', sub: 'Active bans, offline bans and identifier lookup' },
      { id: 'audit', label: 'Audit log', icon: 'log', sub: 'Every staff action, newest first' },
    ] },
    { group: 'Tools', items: [
      { id: 'self', label: 'Self', icon: 'user', sub: 'Personal modes and utilities' },
      { id: 'teleport', label: 'Teleport', icon: 'pin', sub: 'Waypoint, coordinates, places and saved spots' },
      { id: 'vehicles', label: 'Vehicles', icon: 'car', sub: 'Spawn, repair, customise and save vehicles' },
      { id: 'weapons', label: 'Weapons', icon: 'gun', sub: 'Give weapons and weapon modes' },
      { id: 'entities', label: 'Entities', icon: 'box', sub: 'Spawn and clean up props and peds' },
    ] },
    { group: 'Server', items: [
      { id: 'world', label: 'World', icon: 'globe', sub: 'Synced time, weather and area cleanup' },
      { id: 'staff', label: 'Staff', icon: 'shield', sub: 'Announcements, resources and your permissions' },
      { id: 'dev', label: 'Developer', icon: 'code', sub: 'Debug overlay and hashes' },
    ] },
  ];
  const SECTION = {};
  SECTIONS.forEach((g) => g.items.forEach((s) => { SECTION[s.id] = s; }));

  // Icons for individual actions (falls back to the section icon)
  const ACTION_ICON = {
    'self.noclip': 'ghost', 'self.godmode': 'shield', 'self.invisibility': 'eyeOff', 'self.superjump': 'jump',
    'self.fastrun': 'run', 'self.infstamina': 'zap', 'self.infoxygen': 'wind', 'self.heal': 'heart', 'self.armor': 'vest',
    'self.revive': 'plus', 'self.ragdoll': 'rotate', 'self.freeze': 'snow', 'self.wanted.disable': 'star',
    'self.overlay.names': 'tag', 'self.overlay.blips': 'pin', 'self.overlay.ids': 'hash',
    'self.copy.vector3': 'vector', 'self.copy.vector4': 'vector', 'self.copy.heading': 'compass',
    'self.clear.blood': 'droplet', 'self.clear.wetness': 'sun',
    'veh.repair': 'wrench', 'veh.wash': 'droplet', 'veh.flip': 'rotate', 'veh.engine.on': 'power', 'veh.engine.off': 'power',
    'veh.boost': 'rocket', 'veh.enter': 'seat', 'veh.godmode': 'shield', 'veh.freeze': 'snow', 'veh.drift': 'wind',
    'veh.delete': 'trash', 'veh.deleteNearby': 'trash',
    'weap.giveAll': 'plus', 'weap.removeAll': 'trash', 'weap.refill': 'refresh', 'weap.maxclip': 'layers',
    'weap.infammo': 'zap', 'weap.noreload': 'refresh', 'weap.norecoil': 'vector',
    'tp.waypoint': 'flag', 'tp.toPlayer': 'arrowIn', 'tp.bring': 'arrowOut',
    'ply.spectate': 'eye', 'ply.spectate.stop': 'stop', 'ply.teleportTo': 'arrowIn', 'ply.bring': 'arrowOut',
    'ply.freeze': 'snow', 'ply.heal': 'heart', 'ply.revive': 'plus', 'ply.armor': 'vest', 'ply.strip': 'gun',
    'ply.kick': 'kick', 'ply.warn': 'alert', 'ply.ban': 'ban', 'ply.copyIds': 'copy', 'ply.mute': 'micOff', 'ply.unmute': 'mic',
    'ply.screenshot': 'camera',
    'world.freezeTime': 'clock', 'world.blackout': 'bulb', 'world.clearPeds': 'broom', 'world.clearVehicles': 'broom', 'world.clearAll': 'broom',
    'dev.overlay': 'terminal', 'dev.copyVehHash': 'hash', 'dev.copyWeapHash': 'hash',
    'ent.prop.deleteLast': 'trash', 'ent.prop.deleteNearby': 'trash', 'ent.ped.deleteLast': 'trash', 'ent.ped.deleteNearby': 'trash',
    'staff.announce': 'megaphone', 'staff.restart': 'refresh', 'audit.refresh': 'refresh',
  };
  const WEATHER_ICON = {
    CLEAR: 'sun', EXTRASUNNY: 'sun', CLOUDS: 'cloud', OVERCAST: 'cloud', RAIN: 'rain', THUNDER: 'bolt', CLEARING: 'cloud',
    NEUTRAL: 'cloud', SNOW: 'snow', BLIZZARD: 'snow', SNOWLIGHT: 'snow', XMAS: 'snow', FOGGY: 'fog', HALLOWEEN: 'pumpkin',
  };
  const REASON_PRESETS = ['RDM', 'VDM', 'Fail RP', 'Metagaming', 'Powergaming', 'Toxic behaviour', 'Exploiting', 'Cheating'];

  const state = {
    open: false,
    actions: [], actionSet: new Set(),
    players: [], bans: [], resources: [], aces: [], audit: [],
    locale: {}, config: {}, world: {},
    vehicles: [], weapons: [], props: [], peds: [],
    savedVehicles: [], savedLocations: [],
    toggles: {},
    category: 'players',
    selectedPlayer: null, playerRecord: null, detailTab: 'actions',
    lookupResult: null,
    filters: { players: '', bans: '', audit: '', tp: '', res: '' },
    pick: { veh: '', weap: '', prop: '', ped: '' },
    pickQuery: { veh: '', weap: '', prop: '', ped: '' },
    showOffline: false,
    palette: { open: false, query: '', index: 0, items: [] },
    refreshTimer: null,
  };

  const $ = (id) => document.getElementById(id);
  const app = $('app');
  const content = $('content');
  const nav = $('nav');
  const palette = $('palette');
  const paletteInput = $('palette-input');
  const paletteList = $('palette-list');
  const modal = $('modal');
  const modalForm = $('modal-form');
  const toasts = $('toasts');

  // ── Helpers ────────────────────────────────────────────────────────────
  const t = (key, fallback) => state.locale[key] || fallback || key;
  const can = (id) => state.actionSet.has(id);
  const actionDef = (id) => state.actions.find((a) => a.id === id);
  const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const attrJson = (o) => esc(JSON.stringify(o));

  function post(name, data) {
    return fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({ ok: false }));
  }

  function fuzzy(query, text) {
    if (!query) return true;
    query = query.toLowerCase().trim();
    text = (text || '').toLowerCase();
    if (text.includes(query)) return true;
    let i = 0;
    for (let n = 0; n < text.length && i < query.length; n++) if (text[n] === query[i]) i++;
    return i === query.length;
  }

  function fmtTs(ts) {
    const n = Number(ts);
    if (!n) return '—';
    const d = new Date(n * 1000);
    const pad = (v) => String(v).padStart(2, '0');
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }
  function ago(ts) {
    const n = Number(ts);
    if (!n) return '';
    const s = Math.max(0, Math.floor(Date.now() / 1000 - n));
    if (s < 60) return 'just now';
    if (s < 3600) return `${Math.floor(s / 60)}m ago`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
    return `${Math.floor(s / 86400)}d ago`;
  }

  const AV_COLORS = ['#5576e6', '#7c5ce0', '#d9488f', '#e0663f', '#d19a1d', '#2fa36b', '#1f9bb5', '#5b6b85'];
  function initials(name) {
    const parts = String(name || '?').replace(/[^\p{L}\p{N} ]/gu, ' ').trim().split(/\s+/);
    return ((parts[0] || '?')[0] + (parts[1] ? parts[1][0] : (parts[0] || '')[1] || '')).toUpperCase();
  }
  function avatar(p, size) {
    const color = AV_COLORS[Math.abs(Number(p.id) || 0) % AV_COLORS.length];
    return `<span class="avatar ${size || ''}" style="background:${color}">${esc(initials(p.name))}</span>`;
  }
  function pingClass(ms) { return ms < 80 ? 'good' : (ms < 160 ? 'mid' : 'bad'); }

  function toast(message, level, ms) {
    if (!message) return;
    const el = document.createElement('div');
    el.className = `toast ${level || 'info'}`;
    el.textContent = message;
    toasts.appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 220); }, Number(ms) > 0 ? Number(ms) : 4000);
    while (toasts.children.length > 4) toasts.firstChild.remove();
  }

  function copyText(text) {
    if (!text) return;
    const done = () => post('copied', {});
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done).catch(() => fallbackCopy(text, done));
    } else fallbackCopy(text, done);
  }
  function fallbackCopy(text, done) {
    const ta = document.createElement('textarea');
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); done(); } catch (_) { /* ignore */ }
    ta.remove();
  }

  // Player-targeted actions pick up the selected player automatically
  function isTargetAction(id) {
    return id.startsWith('ply.') || id === 'tp.toPlayer' || id === 'tp.bring';
  }

  function run(id, payload) {
    const def = actionDef(id);
    if (!def) return;
    payload = Object.assign({}, def.payload || {}, payload || {});
    if (isTargetAction(id) && id !== 'ply.spectate.stop') {
      if (!state.selectedPlayer) {
        if (def.kind === 'target' || def.kind === 'confirm') {
          toast('Select a player first', 'warn');
          go('players');
          return;
        }
      } else if (payload.target == null) {
        payload.target = state.selectedPlayer.id;
      }
    }
    if (def.kind === 'confirm') {
      openConfirm(def, payload);
      return;
    }
    post('action', { id, payload });
  }

  // ── UI primitives ──────────────────────────────────────────────────────
  function btn(id, label, opts) {
    if (!can(id)) return '';
    opts = opts || {};
    const icon = opts.icon || ACTION_ICON[id];
    const payload = opts.payload ? ` data-payload="${attrJson(opts.payload)}"` : '';
    return `<button type="button" class="btn ${opts.cls || ''}" data-act="${esc(id)}"${payload} title="${esc(opts.title || label)}">${icon ? ico(icon) : ''}${opts.iconOnly ? '' : `<span>${esc(label)}</span>`}</button>`;
  }

  function tile(id, label, opts) {
    if (!can(id)) return '';
    opts = opts || {};
    const payload = opts.payload ? ` data-payload="${attrJson(opts.payload)}"` : '';
    return `<button type="button" class="tile ${opts.cls || ''}" data-act="${esc(id)}"${payload}>${ico(opts.icon || ACTION_ICON[id] || 'zap')}<span>${esc(label)}</span></button>`;
  }

  function sw(id, label) {
    if (!can(id)) return '';
    const on = !!state.toggles[id];
    return `<button type="button" class="switch${on ? ' on' : ''}" data-act="${esc(id)}" data-toggle="1" aria-pressed="${on}">
      <span class="sw-ico">${ico(ACTION_ICON[id] || 'zap')}</span>
      <span class="sw-label">${esc(label)}<span class="sw-state">${on ? 'On' : 'Off'}</span></span>
      <span class="track"></span></button>`;
  }

  function paintToggles() {
    app.querySelectorAll('.switch[data-act]').forEach((el) => {
      const on = !!state.toggles[el.getAttribute('data-act')];
      el.classList.toggle('on', on);
      el.setAttribute('aria-pressed', on);
      const st = el.querySelector('.sw-state');
      if (st) st.textContent = on ? 'On' : 'Off';
    });
  }

  function mergeToggles(map) {
    if (!map || typeof map !== 'object') return;
    Object.keys(map).forEach((k) => { state.toggles[k] = !!map[k]; });
  }

  function section(title, body, right) {
    if (!body || !String(body).trim()) return '';
    return `<div class="section"><div class="section-head"><h3 class="section-title">${esc(title)}</h3>${right || ''}</div>${body}</div>`;
  }
  function card(title, icon, body, extraCls) {
    if (!body || !String(body).trim()) return '';
    return `<div class="card ${extraCls || ''}">${title ? `<h3 class="card-title">${icon ? ico(icon) : ''}${esc(title)}</h3>` : ''}${body}</div>`;
  }
  const wrapIf = (inner, tpl) => (inner && inner.replace(/\s/g, '') ? tpl(inner) : '');
  const empty = (icon, text) => `<div class="empty">${ico(icon)}<div>${esc(text)}</div></div>`;
  const searchBox = (id, value, placeholder) => `<div class="input-icon">${ico('search')}<input class="input" id="${id}" value="${esc(value)}" placeholder="${esc(placeholder)}" autocomplete="off" spellcheck="false" /></div>`;

  // Catalog picker: searchable grouped list instead of a native <select>
  const PICKERS = {
    veh: { items: () => state.vehicles, group: 'class', value: 'model', label: 'label', act: 'veh.spawn', verb: 'Spawn', noun: 'vehicle', placeholder: 'Search vehicles — adder, police, buzzard…' },
    weap: { items: () => state.weapons, group: 'category', value: 'name', label: 'label', act: 'weap.give', verb: 'Give', noun: 'weapon', placeholder: 'Search weapons' },
    prop: { items: () => state.props, group: 'category', value: 'model', label: 'label', act: 'ent.prop.spawn', verb: 'Spawn', noun: 'prop', placeholder: 'Search props', frozen: true },
    ped: { items: () => state.peds, group: 'category', value: 'model', label: 'label', act: 'ent.ped.spawn', verb: 'Spawn', noun: 'ped', placeholder: 'Search peds', frozen: true },
  };

  function pickerListHtml(key) {
    const P = PICKERS[key];
    const q = state.pickQuery[key];
    const groups = new Map();
    (P.items() || []).forEach((it) => {
      const val = String(it[P.value] || '');
      const lab = String(it[P.label] || val);
      const grp = String(it[P.group] || 'Other');
      if (!fuzzy(q, `${val} ${lab} ${grp}`)) return;
      if (!groups.has(grp)) groups.set(grp, []);
      groups.get(grp).push({ val, lab });
    });
    if (groups.size === 0) return empty('search', 'No matches');
    let out = '';
    groups.forEach((list, grp) => {
      out += `<div class="picker-group">${esc(grp)}</div>`;
      out += list.map((it) => `<button type="button" class="pick${state.pick[key] === it.val ? ' active' : ''}" data-pick="${key}" data-val="${esc(it.val)}">
        <span>${esc(it.lab)}</span><span class="code">${esc(it.val)}</span></button>`).join('');
    });
    return out;
  }

  function pickerSelectedLabel(key) {
    const P = PICKERS[key];
    const v = state.pick[key];
    if (!v) return `<span>No ${P.noun} selected</span>`;
    const it = (P.items() || []).find((x) => String(x[P.value]) === v);
    return `Selected <b>${esc(it ? it[P.label] : v)}</b>`;
  }

  function picker(key) {
    const P = PICKERS[key];
    if (!can(P.act)) return '';
    return `<div class="picker" data-picker="${key}">
      <div class="picker-search">${searchBox(`pk-q-${key}`, state.pickQuery[key], P.placeholder)}</div>
      <div class="picker-list" id="pk-list-${key}">${pickerListHtml(key)}</div>
      <div class="picker-foot">
        <span class="sel" id="pk-sel-${key}">${pickerSelectedLabel(key)}</span>
        ${P.frozen ? `<label class="check"><input type="checkbox" id="pk-frozen-${key}" /> Frozen</label>` : ''}
        <button type="button" class="btn primary" data-pick-run="${key}" ${state.pick[key] ? '' : 'disabled'}>${ico('plus')}<span>${P.verb}</span></button>
      </div>
    </div>`;
  }

  function refreshPicker(key) {
    const list = $(`pk-list-${key}`);
    if (list) list.innerHTML = pickerListHtml(key);
    const sel = $(`pk-sel-${key}`);
    if (sel) sel.innerHTML = pickerSelectedLabel(key);
    const b = app.querySelector(`[data-pick-run="${key}"]`);
    if (b) b.disabled = !state.pick[key];
  }

  // ── Navigation ─────────────────────────────────────────────────────────
  function sectionVisible(id) {
    if (id === 'players') return state.actions.some((a) => a.category === 'players');
    if (id === 'staff') return true;
    return state.actions.some((a) => a.category === id);
  }

  function renderNav() {
    nav.innerHTML = SECTIONS.map((g) => {
      const items = g.items.filter((s) => sectionVisible(s.id));
      if (!items.length) return '';
      return `<div class="nav-group"><div class="nav-label">${esc(g.group)}</div>${items.map((s) => {
        let badge = '';
        if (s.id === 'players') badge = `<span class="nav-badge">${state.players.length}</span>`;
        if (s.id === 'bans' && state.bans.length) badge = `<span class="nav-badge">${state.bans.length}</span>`;
        return `<button type="button" class="nav-item${state.category === s.id ? ' active' : ''}" data-nav="${s.id}" title="${esc(s.label)}">${ico(s.icon)}<span>${esc(s.label)}</span>${badge}</button>`;
      }).join('')}</div>`;
    }).join('');
  }

  function go(cat) {
    if (!SECTION[cat]) return;
    state.category = cat;
    render();
    scheduleRefresh();
    content.scrollTop = 0;
  }

  function renderTargetChip() {
    const chip = $('target-chip');
    const p = state.selectedPlayer;
    chip.classList.toggle('hidden', !p);
    if (!p) return;
    $('target-avatar').outerHTML = avatar(p, 'sm').replace('class="avatar sm"', 'class="avatar sm" id="target-avatar"');
    $('target-name').textContent = p.name;
    $('target-id').textContent = `#${p.id}`;
  }

  function selectPlayer(id) {
    const prev = state.selectedPlayer && state.selectedPlayer.id;
    state.selectedPlayer = state.players.find((p) => p.id === id) || null;
    if (prev !== id) {
      state.playerRecord = null;
      state.detailTab = 'actions';
      if (state.selectedPlayer) post('playerRecord', { target: id });
    }
  }

  // ── Pages ──────────────────────────────────────────────────────────────
  function filteredPlayers() {
    const q = state.filters.players;
    return (state.players || []).filter((p) => fuzzy(q, `${p.id} ${p.name}`));
  }

  function playerRowsHtml() {
    const list = filteredPlayers();
    if (!list.length) return empty('users', state.players.length ? t('players_empty', 'No players match the filter.') : 'Nobody is online.');
    const sel = state.selectedPlayer && state.selectedPlayer.id;
    return list.map((p) => `<button type="button" class="player${sel === p.id ? ' selected' : ''}" data-player="${p.id}">
      ${avatar(p)}
      <span class="grow"><div class="player-name">${esc(p.name)}</div><div class="player-sub">ID ${p.id}${p.bucket ? ` · bucket ${esc(p.bucket)}` : ''}</div></span>
      <span class="ping ${pingClass(p.ping)}">${esc(p.ping)} ms</span>
    </button>`).join('');
  }

  function record(p) {
    return state.playerRecord && state.playerRecord.target === p.id ? state.playerRecord : null;
  }

  function detailHeadHtml(p) {
    const rec = record(p);
    const bucket = rec && rec.bucket != null ? rec.bucket : (p.bucket ?? 0);
    const muted = rec ? !!rec.muted : false;
    return `${avatar(p, 'lg')}
      <div class="grow">
        <div class="detail-name">${esc(p.name)}</div>
        <div class="detail-meta">
          <span class="badge">ID ${p.id}</span>
          <span class="badge ${p.ping < 80 ? 'ok' : (p.ping < 160 ? 'warn' : 'danger')}">${esc(p.ping)} ms</span>
          <span class="badge">Bucket ${esc(bucket)}</span>
          ${muted ? '<span class="badge danger">Muted</span>' : ''}
          ${rec && (rec.warns || []).length ? `<span class="badge warn">${rec.warns.length} warn${rec.warns.length === 1 ? '' : 's'}</span>` : ''}
        </div>
      </div>`;
  }

  function qaGroup(label, buttons) {
    const inner = buttons.join('');
    if (!inner.trim()) return '';
    return `<div class="qa-group"><div class="qa-label">${esc(label)}</div><div class="qa">${inner}</div></div>`;
  }

  function detailBodyHtml(p) {
    const rec = record(p);
    const tab = state.detailTab;
    if (tab === 'actions') {
      const muted = rec ? !!rec.muted : false;
      return `
        ${qaGroup('Watch & move', [btn('ply.spectate', 'Spectate'), btn('ply.spectate.stop', 'Stop'), btn('ply.teleportTo', 'Go to'), btn('ply.bring', 'Bring'), btn('ply.freeze', 'Freeze')])}
        ${qaGroup('Care', [btn('ply.heal', 'Heal'), btn('ply.revive', 'Revive'), btn('ply.armor', 'Armor'), btn('ply.strip', 'Strip guns', { cls: '' })])}
        ${qaGroup('Utility', [muted ? btn('ply.unmute', 'Unmute') : btn('ply.mute', 'Mute'), btn('ply.screenshot', 'Screenshot'), btn('ply.copyIds', 'Copy IDs')])}
        ${qaGroup('Discipline', [btn('ply.warn', 'Warn', { cls: 'danger' }), btn('ply.kick', 'Kick', { cls: 'danger' }), btn('ply.ban', 'Ban', { cls: 'danger' })])}
        ${can('ply.message') ? `<div class="qa-group"><div class="qa-label">Private message</div>
          <form data-act="ply.message" class="inline-form"><input class="input" name="message" maxlength="${state.config.maxAnnounce || 240}" placeholder="Message ${esc(p.name)}…" autocomplete="off" />
          <button class="btn primary icon" type="submit" title="Send">${ico('send')}</button></form></div>` : ''}
        ${can('ply.bucket') ? `<div class="qa-group"><div class="qa-label">Routing bucket</div>
          <form data-act="ply.bucket" class="inline-form"><input class="input" name="bucket" type="number" min="0" max="63" value="${esc(rec && rec.bucket != null ? rec.bucket : (p.bucket || 0))}" />
          <button class="btn" type="submit">Set bucket</button></form><p class="hint">0 is the normal world. 1–63 isolate the player.</p></div>` : ''}`;
    }
    if (tab === 'notes') {
      const notes = (rec && rec.notes) || [];
      return `${can('ply.note') ? `<form data-act="ply.note" class="stack" style="margin-bottom:14px">
          <textarea class="input" name="text" maxlength="240" rows="3" placeholder="Add a staff note (only staff can see this)"></textarea>
          <div class="row" style="justify-content:flex-end"><button class="btn primary" type="submit">${ico('save')}<span>Save note</span></button></div></form>` : ''}
        ${!rec ? `<p class="muted">Loading record…</p>` : (notes.length ? notes.map((n) => `<div class="record"><div class="record-text">${esc(n.text || '')}</div>
          <div class="record-meta">${esc(n.staffName || 'Staff')} · ${fmtTs(n.created)}</div></div>`).join('') : empty('msg', 'No notes yet.'))}`;
    }
    if (tab === 'shots') {
      const shots = (rec && rec.shots) || [];
      return !rec ? `<p class="muted">Loading record…</p>` : (shots.length ? `<div class="shots">${shots.map((x) => `<button type="button" class="shot-row" data-shot="${esc(x.id)}">
          <span class="shot-ic">${ico('camera')}</span><span class="grow"><span class="shot-when">${fmtTs(x.created)}</span>
          <span class="record-meta">${esc(x.staffName || 'Staff')} · ${ago(x.created)}</span></span><span class="shot-open">View</span></button>`).join('')}</div>`
        : empty('camera', 'No screenshots of this player yet.'));
    }
    if (tab === 'warns') {
      const warns = (rec && rec.warns) || [];
      return !rec ? `<p class="muted">Loading record…</p>` : (warns.length ? warns.map((w) => `<div class="record"><div class="record-text">${esc(w.reason || '')}</div>
        <div class="record-meta">${esc(w.staffName || 'Staff')} · ${fmtTs(w.created)} · ${ago(w.created)}</div></div>`).join('') : empty('check', 'Clean record — no warnings.'));
    }
    // identifiers
    const ids = p.identifiers || {};
    const keys = ['license', 'discord', 'fivem', 'steam', 'xbl', 'live'].filter((k) => ids[k]);
    return `<div class="ids">${keys.length ? keys.map((k) => `<div class="id-row"><span class="id-type">${esc(k)}</span>
        <span class="id-val" title="${esc(ids[k])}">${esc(ids[k])}</span>
        <button type="button" class="btn sm icon ghost" data-copy="${esc(ids[k])}" title="Copy">${ico('copy')}</button></div>`).join('') : empty('lock', 'Identifiers are hidden for your permission level.')}</div>`;
  }

  function detailHtml() {
    const p = state.selectedPlayer;
    if (!p) return `<div class="detail">${empty('user', 'Select a player to see actions, notes, warnings and identifiers.')}</div>`;
    const rec = record(p);
    const nNotes = rec ? (rec.notes || []).length : '';
    const nWarns = rec ? (rec.warns || []).length : '';
    const nShots = rec ? (rec.shots || []).length : '';
    const tabs = [['actions', 'Actions', ''], ['notes', 'Notes', nNotes], ['warns', 'Warnings', nWarns]];
    if (can('ply.screenshot')) tabs.push(['shots', 'Screenshots', nShots]);
    tabs.push(['ids', 'Identifiers', '']);
    return `<div class="detail">
      <div class="detail-head" id="detail-head">${detailHeadHtml(p)}</div>
      <div class="detail-tabs">${tabs.map(([id, label, n]) => `<button type="button" class="${state.detailTab === id ? 'active' : ''}" data-dtab="${id}">${label}${n !== '' ? `<span class="count">${n}</span>` : ''}</button>`).join('')}</div>
      <div class="detail-body" id="detail-body">${detailBodyHtml(p)}</div>
    </div>`;
  }

  function renderPlayers() {
    return `<div class="split">
      <div class="players-pane">
        <div class="players-tools">
          <div class="grow">${searchBox('f-players', state.filters.players, 'Search by name or ID')}</div>
          <button type="button" class="btn" id="btn-refresh-players" title="Refresh">${ico('refresh')}<span>Refresh</span></button>
        </div>
        <div class="players-list" id="player-list">${playerRowsHtml()}</div>
      </div>
      <div id="player-detail" style="min-height:0;display:flex;flex-direction:column">${detailHtml()}</div>
    </div>`;
  }

  function renderSelf() {
    const acts = state.actions.filter((a) => a.category === 'self');
    const modes = ['self.noclip', 'self.godmode', 'self.invisibility', 'self.superjump', 'self.fastrun', 'self.infstamina', 'self.infoxygen', 'self.freeze', 'self.wanted.disable'];
    const overlays = ['self.overlay.names', 'self.overlay.ids', 'self.overlay.blips'];
    const label = (id) => (actionDef(id) || {}).label || id;
    const wanted = acts.filter((a) => /^self\.wanted\.\d$/.test(a.id)).sort((a, b) => a.id.localeCompare(b.id));
    return `
      ${section('Modes', wrapIf(modes.map((id) => sw(id, label(id))).join(''), (s) => `<div class="switches">${s}</div>`))}
      ${section('Quick actions', wrapIf([tile('self.heal', 'Heal'), tile('self.armor', 'Full armor'), tile('self.revive', 'Revive'), tile('self.ragdoll', 'Ragdoll'), tile('self.clear.blood', 'Clear blood'), tile('self.clear.wetness', 'Dry off')].join(''), (s) => `<div class="tiles">${s}</div>`))}
      <div class="cols-2">
        ${wrapIf([tile('self.copy.vector3', 'vector3'), tile('self.copy.vector4', 'vector4'), tile('self.copy.heading', 'Heading')].join(''), (s) => card('Copy position', 'copy', `<div class="tiles">${s}</div>`))}
        ${wanted.length ? card('Wanted level', 'star', `<div class="seg">${wanted.map((a) => `<button type="button" data-act="${a.id}">${'★'.repeat(Number(a.id.slice(-1)))}</button>`).join('')}</div><p class="hint">Sets your wanted level instantly. Use “Disable wanted” in Modes to keep it at zero.</p>`) : ''}
      </div>
      ${section('Overlays', wrapIf(overlays.map((id) => sw(id, label(id))).join(''), (s) => `<div class="switches">${s}</div>`))}`;
  }

  function numForm(id, label, name, min, max, value, cta) {
    if (!can(id)) return '';
    return `<form data-act="${id}" class="list-row"><span class="grow">${esc(label)} <span class="faint">${min}–${max}</span></span>
      <input class="input" style="width:76px" name="${name}" type="number" min="${min}" max="${max}" value="${value}" />
      <button class="btn sm" type="submit">${esc(cta)}</button></form>`;
  }

  function renderVehicles() {
    const cur = [tile('veh.repair', 'Repair'), tile('veh.wash', 'Wash'), tile('veh.flip', 'Flip'), tile('veh.engine.on', 'Engine on'), tile('veh.engine.off', 'Engine off'), tile('veh.boost', 'Boost'), tile('veh.enter', 'Enter as driver')].join('');
    const body = ['veh.door.0', 'veh.door.1', 'veh.door.2', 'veh.door.3', 'veh.hood', 'veh.trunk', 'veh.windows'];
    const bodyLabels = { 'veh.door.0': 'Front left', 'veh.door.1': 'Front right', 'veh.door.2': 'Rear left', 'veh.door.3': 'Rear right', 'veh.hood': 'Hood', 'veh.trunk': 'Trunk', 'veh.windows': 'Windows' };
    const custom = [
      numForm('veh.extras', 'Extra', 'extra', 1, 14, 1, 'Toggle'),
      numForm('veh.livery', 'Livery', 'livery', 0, 40, 0, 'Apply'),
      numForm('veh.xenon', 'Xenon colour', 'color', 0, 12, 0, 'Apply'),
      numForm('veh.tint', 'Window tint', 'tint', 0, 6, 1, 'Apply'),
      can('veh.plate') ? `<form data-act="veh.plate" class="list-row"><span class="grow">Plate</span>
        <input class="input" style="width:130px;text-transform:uppercase" name="plate" maxlength="${state.config.maxPlate || 8}" placeholder="ADMIN" />
        <button class="btn sm" type="submit">Apply</button></form>` : '',
    ].join('');
    const saved = state.savedVehicles || [];
    const garage = (can('veh.save') || can('veh.saved.spawn')) ? `
      ${can('veh.save') ? `<form data-act="veh.save" class="inline-form" style="margin-bottom:10px"><input class="input" name="name" placeholder="Name the vehicle you're in" maxlength="32" /><button class="btn primary" type="submit">${ico('save')}<span>Save</span></button></form>` : ''}
      ${saved.length ? `<div class="list">${saved.map((v) => `<div class="list-row">${ico('car')}<span class="grow">${esc(v.name)} <span class="faint mono">${esc(v.model || '')}</span></span>
          ${btn('veh.saved.spawn', 'Spawn', { cls: 'sm', icon: 'plus', payload: { id: v.id } })}
          ${btn('veh.saved.delete', 'Delete', { cls: 'sm ghost icon', iconOnly: true, icon: 'trash', payload: { id: v.id } })}</div>`).join('')}</div>` : empty('car', 'No saved vehicles yet.')}` : '';
    return `<div class="cols-2">
      <div class="stack">
        ${card('Spawn vehicle', 'plus', picker('veh'))}
        ${card('Garage', 'save', garage)}
      </div>
      <div class="stack">
        ${card('Current vehicle', 'car', wrapIf(cur, (s) => `<div class="tiles">${s}</div>`) + wrapIf([sw('veh.godmode', 'Godmode'), sw('veh.freeze', 'Freeze'), sw('veh.drift', 'Drift tires')].join(''), (s) => `<div class="switches" style="margin-top:10px">${s}</div>`))}
        ${card('Doors & windows', 'door', wrapIf(body.map((id) => btn(id, bodyLabels[id], { cls: 'sm' })).join(''), (s) => `<div class="row">${s}</div>`))}
        ${card('Customise', 'wrench', wrapIf(custom, (s) => `<div class="list">${s}</div>`))}
        ${card('Remove', 'trash', wrapIf([btn('veh.delete', 'Delete current', { cls: 'danger' }), btn('veh.deleteNearby', `Delete nearby (${state.config.deleteRadius || 8} m)`, { cls: 'danger' })].join(''), (s) => `<div class="row">${s}</div>`))}
      </div>
    </div>`;
  }

  function renderWeapons() {
    return `<div class="cols-2">
      ${card('Give weapon', 'plus', picker('weap'))}
      <div class="stack">
        ${card('Loadout', 'gun', wrapIf([tile('weap.giveAll', 'Give all'), tile('weap.refill', 'Refill ammo'), tile('weap.maxclip', 'Max clip'), tile('weap.removeAll', 'Remove all', { cls: 'danger' })].join(''), (s) => `<div class="tiles">${s}</div>`))}
        ${card('Modes', 'zap', wrapIf([sw('weap.infammo', 'Infinite ammo'), sw('weap.noreload', 'No reload'), sw('weap.norecoil', 'No recoil')].join(''), (s) => `<div class="switches">${s}</div>`))}
      </div>
    </div>`;
  }

  function renderEntities() {
    const col = (key, title, icon, last, near) => {
      const tools = [btn(last, 'Delete last', { cls: 'danger' }), btn(near, `Delete nearby (${state.config.deleteRadius || 8} m)`, { cls: 'danger' })].join('');
      return card(title, icon, picker(key) + wrapIf(tools, (s) => `<div class="row" style="margin-top:12px">${s}</div>`));
    };
    return `<div class="cols-2">
      ${col('prop', 'Props', 'box', 'ent.prop.deleteLast', 'ent.prop.deleteNearby')}
      ${col('ped', 'Peds', 'user', 'ent.ped.deleteLast', 'ent.ped.deleteNearby')}
    </div><p class="hint">Models are validated by the server and spawn in front of you. Nearby delete is capped at 40 entities.</p>`;
  }

  function locationGridHtml() {
    const locs = (state.config.locations || []).filter((l) => can('tp.location.' + l.id) && fuzzy(state.filters.tp, `${l.id} ${l.label}`));
    if (!locs.length) return empty('pin', (state.config.locations || []).length ? 'No places match.' : 'No places configured.');
    return `<div class="loc-grid">${locs.map((l) => `<button type="button" class="loc" data-act="tp.location.${esc(l.id)}">${ico('pin')}<span>${esc(l.label)}</span></button>`).join('')}</div>`;
  }

  function renderTeleport() {
    const sel = state.selectedPlayer;
    const quick = [tile('tp.waypoint', 'To waypoint'), tile('tp.toPlayer', sel ? `To ${sel.name}` : 'To target'), tile('tp.bring', sel ? `Bring ${sel.name}` : 'Bring target')].join('');
    const coords = can('tp.coords') ? `
      <div class="field"><label>Paste coordinates</label><input class="input" id="tp-paste" placeholder="vector3(195.1, -933.7, 30.6) or 195.1, -933.7, 30.6" autocomplete="off" /></div>
      <form data-act="tp.coords">
        <div class="coords">
          <div class="field"><label>X</label><input class="input" name="x" required inputmode="decimal" /></div>
          <div class="field"><label>Y</label><input class="input" name="y" required inputmode="decimal" /></div>
          <div class="field"><label>Z</label><input class="input" name="z" required inputmode="decimal" /></div>
          <div class="field"><label>Heading</label><input class="input" name="w" value="0" inputmode="decimal" /></div>
        </div>
        <button class="btn primary block" type="submit">${ico('pin')}<span>Teleport</span></button>
      </form>` : '';
    const saved = state.savedLocations || [];
    const personal = (can('tp.saveLocation') || can('tp.saved')) ? `
      ${can('tp.saveLocation') ? `<form data-act="tp.saveLocation" class="inline-form" style="margin-bottom:10px"><input class="input" name="name" placeholder="Name this spot" maxlength="32" /><button class="btn primary" type="submit">${ico('save')}<span>Save here</span></button></form>` : ''}
      ${saved.length ? `<div class="list">${saved.map((l) => `<div class="list-row">${ico('pin')}<span class="grow">${esc(l.name)}</span>
        ${btn('tp.saved', 'Go', { cls: 'sm', icon: 'arrowIn', payload: { id: l.id } })}
        ${btn('tp.saved.delete', 'Delete', { cls: 'sm ghost icon', iconOnly: true, icon: 'trash', payload: { id: l.id } })}</div>`).join('')}</div>` : empty('pin', 'No saved spots yet.')}` : '';
    return `
      ${section('Quick', wrapIf(quick, (s) => `<div class="tiles">${s}</div>`))}
      <div class="cols-2">
        <div class="stack">${card('Coordinates', 'vector', coords)}${card('My spots', 'save', personal)}</div>
        ${card('Places', 'globe', `<div style="margin-bottom:10px">${searchBox('f-tp', state.filters.tp, 'Filter places')}</div><div id="tp-grid">${locationGridHtml()}</div>`)}
      </div>`;
  }

  function renderWorld() {
    const w = state.world || {};
    const hour = Number(w.hour ?? 12);
    const minute = Number(w.minute ?? 0);
    const pad = (n) => String(n).padStart(2, '0');
    const weather = (state.config.weather || []).filter((n) => can('world.weather.' + n));
    const time = can('world.time') || can('world.time.noon') ? `
      ${can('world.time') ? `<form data-act="world.time">
        <div class="row" style="justify-content:space-between;margin-bottom:12px"><div class="clock" id="clock">${pad(hour)}:${pad(minute)}</div>
          <button class="btn primary" type="submit">${ico('check')}<span>Apply time</span></button></div>
        <div class="field"><label>Hour</label><input class="range" type="range" name="hour" min="0" max="23" value="${hour}" data-clock="h" /></div>
        <div class="field"><label>Minute</label><input class="range" type="range" name="minute" min="0" max="59" step="5" value="${minute - (minute % 5)}" data-clock="m" /></div>
      </form>` : ''}
      ${wrapIf([['world.time.morning', 'Morning'], ['world.time.noon', 'Noon'], ['world.time.evening', 'Evening'], ['world.time.night', 'Night']].map(([id, l]) => can(id) ? `<button type="button" data-act="${id}">${l}</button>` : '').join(''), (s) => `<div class="seg">${s}</div>`)}
      ${wrapIf(sw('world.freezeTime', 'Freeze time'), (s) => `<div style="margin-top:12px">${s}</div>`)}` : '';
    const weatherHtml = weather.length ? `<div class="weather-grid">${weather.map((n) => `<button type="button" class="weather${w.weather === n ? ' active' : ''}" data-act="world.weather.${esc(n)}">${ico(WEATHER_ICON[n] || 'cloud')}<span>${esc(n.charAt(0) + n.slice(1).toLowerCase())}</span></button>`).join('')}</div>` : '';
    return `<div class="cols-2">
      ${card('Time', 'clock', time)}
      <div class="stack">
        ${card('Weather', 'cloud', weatherHtml + wrapIf(sw('world.blackout', 'Blackout'), (s) => `<div style="margin-top:12px">${s}</div>`))}
        ${card(`Clear area · ${state.config.clearRadius || 80} m`, 'broom', wrapIf([tile('world.clearPeds', 'Peds'), tile('world.clearVehicles', 'Vehicles'), tile('world.clearAll', 'Everything')].join(''), (s) => `<div class="tiles">${s}</div>`))}
      </div>
    </div>`;
  }

  function lookupHtml() {
    const r = state.lookupResult;
    if (!r) return '';
    if (r.error) return `<p class="field-error" style="margin-top:10px">${esc(t('lookup_invalid', 'Could not parse that identifier.'))}</p>`;
    const bans = r.bans || []; const notes = r.notes || []; const warns = r.warns || [];
    const block = (title, list, fn) => list.length ? `<div class="qa-label" style="margin-top:12px">${title}</div>${list.map(fn).join('')}` : '';
    return `<div class="divider"></div>
      <div class="row"><span class="mono grow" style="overflow:hidden;text-overflow:ellipsis">${esc(r.license || 'no license')}</span>
        <span class="badge ${bans.length ? 'danger' : 'ok'}">${bans.length} bans</span><span class="badge warn">${warns.length} warns</span><span class="badge">${notes.length} notes</span>${r.muted ? '<span class="badge danger">Muted</span>' : ''}</div>
      ${block('Bans', bans, (b) => `<div class="record"><div class="record-text"><b>${esc(b.name || '')}</b> — ${esc(b.reason || '')}</div><div class="record-meta">${fmtTs(b.created)} · ${b.expires ? 'until ' + fmtTs(b.expires) : 'permanent'}</div></div>`)}
      ${block('Warnings', warns, (w) => `<div class="record"><div class="record-text">${esc(w.reason || '')}</div><div class="record-meta">${esc(w.staffName || '')} · ${fmtTs(w.created)}</div></div>`)}
      ${block('Notes', notes, (n) => `<div class="record"><div class="record-text">${esc(n.text || '')}</div><div class="record-meta">${esc(n.staffName || '')} · ${fmtTs(n.created)}</div></div>`)}
      ${!bans.length && !notes.length && !warns.length && !r.muted ? `<p class="hint">${esc(t('lookup_empty', 'No records for that identifier.'))}</p>` : ''}`;
  }

  function banRowsHtml() {
    const list = (state.bans || []).filter((b) => fuzzy(state.filters.bans, `${b.name} ${b.reason} ${(b.identifiers && b.identifiers.license) || ''}`));
    if (!list.length) return empty('ban', state.bans.length ? 'No bans match.' : t('bans_empty', 'No bans on record.'));
    return `<table><thead><tr><th>Player</th><th>Reason</th><th>Issued</th><th>Expires</th><th class="right"></th></tr></thead><tbody>
      ${list.map((b) => `<tr>
        <td><b>${esc(b.name || 'Unknown')}</b><div class="cell-sub mono">${esc((b.identifiers && b.identifiers.license) || '')}</div></td>
        <td>${esc(b.reason || '')}${b.staffName ? `<div class="cell-sub">by ${esc(b.staffName)}</div>` : ''}</td>
        <td class="muted">${b.created ? ago(b.created) : '—'}</td>
        <td>${b.expires ? `<span class="badge warn">${fmtTs(b.expires)}</span>` : '<span class="badge danger">Permanent</span>'}</td>
        <td class="right">${btn('ban.unban', 'Unban', { cls: 'sm', icon: 'check', payload: { banId: b.id } })}</td>
      </tr>`).join('')}</tbody></table>`;
  }

  function renderBans() {
    const durs = (state.config.banDurations || []);
    const offline = can('ban.offline') && state.showOffline ? card('Ban an offline player', 'ban', `
      <form data-act="ban.offline">
        <div class="cols-2" style="gap:12px">
          <div class="field"><label>License</label><input class="input" name="license" required placeholder="license:abc123… or abc123…" maxlength="96" /></div>
          <div class="field"><label>Name <span class="faint">(optional)</span></label><input class="input" name="name" maxlength="64" /></div>
          <div class="field"><label>Discord <span class="faint">(optional)</span></label><input class="input" name="discord" placeholder="discord:123… or 123…" maxlength="80" /></div>
          <div class="field"><label>Duration</label><select class="input" name="durationId">${durs.map((d) => `<option value="${esc(d.id)}">${esc(d.label)}</option>`).join('')}</select></div>
        </div>
        <div class="field"><label>${esc(t('reason_placeholder', 'Reason'))}</label><input class="input" name="reason" required minlength="${state.config.minReason || 3}" maxlength="${state.config.maxReason || 200}" /></div>
        <div class="row" style="justify-content:flex-end"><button type="button" class="btn ghost" id="btn-offline-cancel">Cancel</button><button class="btn solid-danger" type="submit">${ico('ban')}<span>Ban</span></button></div>
      </form>`) : '';
    const lookup = can('ban.lookup') ? card('Identifier lookup', 'search', `
      <form data-act="ban.lookup" class="inline-form"><input class="input" name="query" required placeholder="license:…  discord:…  steam:…" maxlength="96" /><button class="btn primary" type="submit">Look up</button></form>
      ${lookupHtml()}`) : '';
    return `<div class="toolbar">
        ${searchBox('f-bans', state.filters.bans, 'Search bans by name, reason or license')}
        <span class="grow"></span>
        <button type="button" class="btn" id="btn-refresh-bans">${ico('refresh')}<span>Refresh</span></button>
        ${can('ban.offline') ? `<button type="button" class="btn danger" id="btn-offline">${ico('ban')}<span>Offline ban</span></button>` : ''}
      </div>
      ${offline ? `<div style="margin-bottom:14px">${offline}</div>` : ''}
      <div class="split" style="grid-template-columns:minmax(0,1fr) 360px">
        <div class="table-wrap" id="ban-table">${banRowsHtml()}</div>
        <div>${lookup}</div>
      </div>`;
  }

  function auditBadge(action) {
    const a = String(action || '');
    if (/ban|kick/.test(a)) return 'danger';
    if (/warn|mute|freeze|strip/.test(a)) return 'warn';
    if (/spawn|give|tp|teleport/.test(a)) return 'accent';
    return '';
  }

  function auditRowsHtml() {
    const list = (state.audit || []).filter((e) => fuzzy(state.filters.audit, `${e.staffName || ''} ${e.action || ''} ${e.targetName || ''} ${e.detail || ''} ${e.license || ''}`));
    if (!list.length) return empty('log', t('audit_empty', 'No audit entries.'));
    return `<table><thead><tr><th style="width:150px">When</th><th>Staff</th><th>Action</th><th>Target</th><th>Detail</th></tr></thead><tbody>
      ${list.map((e) => `<tr>
        <td><div>${ago(e.ts)}</div><div class="cell-sub mono">${fmtTs(e.ts)}</div></td>
        <td>${esc(e.staffName || '')}</td>
        <td><span class="badge ${auditBadge(e.action)}">${esc(e.action || '')}</span></td>
        <td>${esc(e.targetName || '')}${e.target != null ? ` <span class="faint">#${esc(e.target)}</span>` : ''}${e.license ? `<div class="cell-sub mono">${esc(e.license)}</div>` : ''}</td>
        <td class="muted">${esc(e.detail || '')}</td>
      </tr>`).join('')}</tbody></table>`;
  }

  function renderAudit() {
    if (!can('audit.refresh')) return empty('lock', 'You do not have permission to view the audit log.');
    return `<div class="toolbar">${searchBox('f-audit', state.filters.audit, 'Filter by staff, action, target or detail')}<span class="grow"></span>
        <button type="button" class="btn" id="btn-refresh-audit">${ico('refresh')}<span>Refresh</span></button></div>
      <div class="table-wrap" id="audit-table">${auditRowsHtml()}</div>`;
  }

  function resourceRowsHtml() {
    const list = (state.resources || []).filter((r) => fuzzy(state.filters.res, r.name));
    if (!list.length) return empty('box', t('resources_empty', 'No resources found.'));
    const stateBadge = (s) => s === 'started' ? 'ok' : (s === 'stopped' ? 'danger' : 'warn');
    return `<table><thead><tr><th>Resource</th><th>State</th><th class="right"></th></tr></thead><tbody>
      ${list.map((r) => `<tr><td class="mono">${esc(r.name)}</td><td><span class="badge ${stateBadge(r.state)}"><span class="dot"></span>${esc(r.state)}</span></td>
        <td class="right">${r.name === 'fivex_admin' ? '<span class="faint">protected</span>' : btn('staff.restart', 'Restart', { cls: 'sm', payload: { resource: r.name } })}</td></tr>`).join('')}
    </tbody></table>`;
  }

  function renderStaff() {
    const max = state.config.maxAnnounce || 240;
    const announce = can('staff.announce') ? `<form data-act="staff.announce">
        <div class="field"><textarea class="input" name="message" id="announce-input" maxlength="${max}" rows="4" placeholder="Server restart in 10 minutes — please find a safe spot."></textarea>
        <div class="counter"><span id="announce-count">0</span> / ${max}</div></div>
        <div class="row" style="justify-content:flex-end"><button class="btn primary" type="submit">${ico('megaphone')}<span>Broadcast to everyone</span></button></div>
      </form>` : `<p class="muted">You don't have the announce permission.</p>`;
    const res = can('staff.restart') ? `<div style="margin-bottom:10px" class="row nowrap"><div class="grow">${searchBox('f-res', state.filters.res, 'Filter resources')}</div><button type="button" class="btn" id="btn-refresh-res">${ico('refresh')}</button></div>
      <div class="table-wrap" id="res-table">${resourceRowsHtml()}</div>` : `<p class="muted">You don't have the resource permission.</p>`;
    // left column scrolls on its own; the resources card takes the full height of the page
    return `<div class="cols-2 staff-grid">
      <div class="stack staff-side">
        ${card('Announcement', 'megaphone', announce)}
        ${card('Your permissions', 'lock', `<div class="row">${(state.aces || []).map((a) => `<span class="badge">${esc(a)}</span>`).join('') || '<span class="muted">None listed</span>'}</div>`)}
      </div>
      ${card('Resources', 'box', res, 'card-fill')}
    </div>`;
  }

  function renderDev() {
    return `${section('Overlay', wrapIf(sw('dev.overlay', 'Coordinates, speed and aimed entity'), (s) => `<div class="switches">${s}</div>`))}
      ${section('Copy to clipboard', wrapIf([tile('dev.copyVehHash', 'Vehicle hash'), tile('dev.copyWeapHash', 'Weapon hash'), tile('self.copy.vector3', 'vector3'), tile('self.copy.vector4', 'vector4')].join(''), (s) => `<div class="tiles">${s}</div>`))}`;
  }

  const PAGES = {
    players: renderPlayers, self: renderSelf, vehicles: renderVehicles, weapons: renderWeapons, entities: renderEntities,
    teleport: renderTeleport, world: renderWorld, bans: renderBans, audit: renderAudit, staff: renderStaff, dev: renderDev,
  };
  const FILL = { players: 1, audit: 1, bans: 1, staff: 1 };

  function render() {
    renderNav();
    renderTargetChip();
    const s = SECTION[state.category] || SECTION.players;
    $('page-title').textContent = s.label;
    $('page-sub').textContent = s.id === 'players' ? `${state.players.length} online · ${s.sub}` : s.sub;
    content.innerHTML = (PAGES[state.category] || renderPlayers)();
    content.classList.toggle('fill', !!FILL[state.category]);
    content.querySelectorAll('input.range').forEach(paintRange);
    $('brand-sub').textContent = `${state.players.length} online · ${state.actions.length} actions`;
  }

  // Screenshot viewer: the image is read from the database only when it is opened
  function openShot(id) {
    state.shotId = id;
    $('shot-title').textContent = 'Screenshot';
    $('shot-meta').textContent = '';
    $('shot-frame').innerHTML = '<div class="muted">Loading…</div>';
    $('shot-view').classList.remove('hidden');
    post('screenshotImage', { id });
  }
  function closeShot() {
    state.shotId = null;
    $('shot-view').classList.add('hidden');
    $('shot-frame').innerHTML = '';
  }

  // Range sliders: the filled part of the track follows the value (--p, 0–100%)
  function paintRange(el) {
    const min = Number(el.min) || 0, max = Number(el.max) || 100;
    const p = max > min ? ((Number(el.value) - min) / (max - min)) * 100 : 0;
    el.style.setProperty('--p', `${p}%`);
  }

  // Live player refresh: only touch what changed so inputs keep focus
  function refreshPlayersLive(lostSelection) {
    renderNav();
    renderTargetChip();
    if (state.category === 'players') {
      $('page-sub').textContent = `${state.players.length} online · ${SECTION.players.sub}`;
      const list = $('player-list');
      if (list) list.innerHTML = playerRowsHtml();
      if (lostSelection) {
        const d = $('player-detail');
        if (d) d.innerHTML = detailHtml();
      } else if (state.selectedPlayer) {
        const head = $('detail-head');
        if (head) head.innerHTML = detailHeadHtml(state.selectedPlayer);
      }
    } else if (lostSelection && state.category === 'teleport') {
      render();
    }
  }

  function refreshDetailBody() {
    const d = $('player-detail');
    if (d) d.innerHTML = detailHtml();
  }

  function scheduleRefresh() {
    if (state.refreshTimer) { clearInterval(state.refreshTimer); state.refreshTimer = null; }
    if (!state.open || state.category !== 'players') return;
    post('refreshPlayers', {});
    state.refreshTimer = setInterval(() => {
      if (state.open && state.category === 'players') post('refreshPlayers', {});
    }, state.config.playerRefreshMs || 4000);
  }

  // ── Confirm modal ─────────────────────────────────────────────────────
  const CONFIRM_COPY = {
    'ply.kick': ['Kick player', 'kick', 'They can reconnect straight away.', 'Kick'],
    'ply.ban': ['Ban player', 'ban', 'They are removed and blocked from joining.', 'Ban'],
    'ply.warn': ['Warn player', 'alert', 'The warning is shown to them and saved to their record.', 'Warn'],
    'ban.unban': ['Remove ban', 'check', 'They will be able to join again.', 'Unban'],
    'veh.delete': ['Delete vehicle', 'trash', 'Deletes the vehicle you are in.', 'Delete'],
    'veh.deleteNearby': ['Delete nearby vehicles', 'trash', 'Deletes unoccupied vehicles around you.', 'Delete'],
    'staff.restart': ['Restart resource', 'refresh', 'Players may notice a short interruption.', 'Restart'],
  };

  function openConfirm(def, payload) {
    const copy = CONFIRM_COPY[def.id] || [t('confirm_title', 'Confirm action'), 'alert', def.label, 'Confirm'];
    const target = payload.target != null ? state.players.find((p) => p.id === payload.target) : null;
    $('modal-title').textContent = target ? `${copy[0]}: ${target.name}` : (def.id === 'staff.restart' && payload.resource ? `${copy[0]}: ${payload.resource}` : copy[0]);
    $('modal-body').textContent = copy[2];
    const iconEl = $('modal-icon');
    iconEl.innerHTML = ico(copy[1]);
    iconEl.classList.toggle('info', def.id === 'ban.unban');
    const ok = $('modal-ok');
    ok.textContent = copy[3];
    ok.className = def.id === 'ban.unban' ? 'btn primary' : 'btn solid-danger';

    const fields = $('modal-fields');
    fields.innerHTML = '';
    const needsReason = def.id === 'ply.kick' || def.id === 'ply.ban' || def.id === 'ply.warn';
    if (needsReason) {
      fields.insertAdjacentHTML('beforeend', `<div class="field"><label>${esc(t('reason_placeholder', 'Reason'))}</label>
        <input class="input" name="reason" autocomplete="off" minlength="${state.config.minReason || 3}" maxlength="${state.config.maxReason || 200}" placeholder="What happened?" /></div>
        <div class="presets">${REASON_PRESETS.map((r) => `<button type="button" class="preset" data-preset="${esc(r)}">${esc(r)}</button>`).join('')}</div>
        <div class="field-error hidden" id="modal-error"></div>`);
    }
    if (def.id === 'ply.ban') {
      const durs = state.config.banDurations || [];
      const first = durs[0] ? durs[0].id : '';
      fields.insertAdjacentHTML('beforeend', `<div class="field"><label>${esc(t('duration_label', 'Duration'))}</label>
        <div class="seg" id="dur-seg">${durs.map((d) => `<button type="button" class="${d.id === first ? 'active' : ''}" data-dur="${esc(d.id)}">${esc(d.label)}</button>`).join('')}</div>
        <input type="hidden" name="durationId" value="${esc(first)}" /></div>`);
    }
    modal.dataset.action = def.id;
    modal.dataset.payload = JSON.stringify(payload || {});
    modal.classList.remove('hidden');
    const firstInput = fields.querySelector('input:not([type=hidden])');
    (firstInput || ok).focus();
  }

  modal.addEventListener('click', (e) => {
    if (e.target === modal) { modal.classList.add('hidden'); return; }
    const pre = e.target.closest('[data-preset]');
    if (pre) {
      const input = modalForm.querySelector('input[name="reason"]');
      if (input) { input.value = input.value ? `${input.value}, ${pre.dataset.preset}` : pre.dataset.preset; input.focus(); }
      return;
    }
    const dur = e.target.closest('[data-dur]');
    if (dur) {
      modalForm.querySelectorAll('[data-dur]').forEach((b) => b.classList.toggle('active', b === dur));
      const hidden = modalForm.querySelector('input[name="durationId"]');
      if (hidden) hidden.value = dur.dataset.dur;
    }
  });

  modalForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const id = modal.dataset.action;
    const payload = JSON.parse(modal.dataset.payload || '{}');
    const reason = modalForm.querySelector('input[name="reason"]');
    if (reason) {
      const v = reason.value.trim();
      const min = state.config.minReason || 3;
      if (v.length < min) {
        const err = $('modal-error');
        err.textContent = `Please give a reason (at least ${min} characters).`;
        err.classList.remove('hidden');
        reason.focus();
        return;
      }
    }
    new FormData(modalForm).forEach((v, k) => { payload[k] = typeof v === 'string' ? v.trim() : v; });
    modal.classList.add('hidden');
    post('action', { id, payload });
  });
  $('modal-cancel').addEventListener('click', () => modal.classList.add('hidden'));
  // the viewer sits outside #app, so it needs its own listener: Close, or a click on the dark backdrop
  $('shot-view').addEventListener('click', (e) => {
    if (e.target.closest('#shot-close') || e.target.id === 'shot-view') closeShot();
  });

  // ── Command palette ───────────────────────────────────────────────────
  // Ranked match: label prefix > word start > substring > keywords/category > loose letters in the label
  function score(q, label, extra) {
    if (!q) return 1;
    const l = String(label || '').toLowerCase();
    if (l.startsWith(q)) return 100;
    if (new RegExp(`(^|[^a-z0-9])${q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`).test(l)) return 80;
    if (l.includes(q)) return 60;
    if (String(extra || '').toLowerCase().includes(q)) return 40;
    if (q.length >= 3 && fuzzy(q, l)) return 10;
    return 0;
  }

  function paletteItems() {
    const q = state.palette.query.trim().toLowerCase();
    const items = [];
    const ranked = (list, fn) => list.map((x) => [x, fn(x)]).filter(([, s]) => s > 0).sort((a, b) => b[1] - a[1]).map(([x]) => x);
    if (q) {
      ranked(state.players || [], (p) => score(q, p.name, String(p.id))).slice(0, 5)
        .forEach((p) => items.push({ type: 'player', id: p.id, label: p.name, sub: `#${p.id}` }));
      ranked(SECTIONS.flatMap((g) => g.items).filter((s) => sectionVisible(s.id)), (s) => score(q, s.label)).slice(0, 3)
        .forEach((s) => items.push({ type: 'page', id: s.id, label: `Go to ${s.label}`, icon: s.icon }));
    }
    ranked(state.actions, (a) => score(q, a.label, `${a.keywords || ''} ${a.category} ${a.id}`)).slice(0, 40)
      .forEach((a) => items.push({ type: 'action', id: a.id, label: a.label, cat: (SECTION[a.category] || {}).label || a.category, icon: ACTION_ICON[a.id] || (SECTION[a.category] || {}).icon }));
    return items;
  }

  function renderPalette() {
    const items = state.palette.items = paletteItems();
    if (state.palette.index >= items.length) state.palette.index = Math.max(0, items.length - 1);
    if (!items.length) { paletteList.innerHTML = '<li class="head">No matches</li>'; return; }
    let lastType = '';
    const heads = { player: 'Players', page: 'Pages', action: 'Actions' };
    paletteList.innerHTML = items.map((it, i) => {
      let head = '';
      if (it.type !== lastType) { head = `<li class="head">${heads[it.type]}</li>`; lastType = it.type; }
      const icon = it.type === 'player' ? ico('user') : ico(it.icon || 'zap');
      const right = it.type === 'player' ? `<span class="pl-cat">${esc(it.sub)}</span>` : (it.cat ? `<span class="pl-cat">${esc(it.cat)}</span>` : '');
      return `${head}<li class="${i === state.palette.index ? 'active' : ''}" data-i="${i}">${icon}<span>${esc(it.label)}</span>${right}</li>`;
    }).join('');
    const active = paletteList.querySelector('li.active');
    if (active) active.scrollIntoView({ block: 'nearest' });
  }

  function openPalette() {
    state.palette.open = true;
    state.palette.query = '';
    state.palette.index = 0;
    palette.classList.remove('hidden');
    paletteInput.value = '';
    renderPalette();
    paletteInput.focus();
  }
  function closePalette() {
    state.palette.open = false;
    palette.classList.add('hidden');
  }

  function activatePaletteItem(it) {
    if (!it) return;
    closePalette();
    if (it.type === 'player') {
      selectPlayer(it.id);
      go('players');
      return;
    }
    if (it.type === 'page') { go(it.id); return; }
    const def = actionDef(it.id);
    if (!def) return;
    if (def.kind === 'form') {
      // forms need input: open their page instead of running with an empty payload
      go(def.category);
      return;
    }
    if (def.kind === 'toggle') state.toggles[def.id] = !state.toggles[def.id];
    run(def.id, {});
    paintToggles();
  }

  paletteInput.addEventListener('input', () => {
    state.palette.query = paletteInput.value;
    state.palette.index = 0;
    renderPalette();
  });
  paletteList.addEventListener('click', (e) => {
    const li = e.target.closest('li[data-i]');
    if (li) activatePaletteItem(state.palette.items[Number(li.dataset.i)]);
  });
  palette.addEventListener('click', (e) => { if (e.target === palette) closePalette(); });

  // ── Events ────────────────────────────────────────────────────────────
  nav.addEventListener('click', (e) => {
    const b = e.target.closest('[data-nav]');
    if (b) go(b.dataset.nav);
  });
  $('btn-palette').addEventListener('click', openPalette);
  $('btn-close').addEventListener('click', () => post('close', {}));
  $('target-clear').addEventListener('click', () => {
    state.selectedPlayer = null;
    state.playerRecord = null;
    render();
  });

  app.addEventListener('click', (e) => {
    const target = e.target;
    if (target.closest('#nav')) return;
    if (target.closest('#btn-refresh-players')) { post('refreshPlayers', {}); return; }
    if (target.closest('#btn-refresh-bans')) { post('refreshBans', {}); return; }
    if (target.closest('#btn-refresh-res')) { post('refreshResources', {}); return; }
    if (target.closest('#btn-refresh-audit')) { run('audit.refresh', {}); return; }
    if (target.closest('#btn-offline')) { state.showOffline = !state.showOffline; render(); return; }
    if (target.closest('#btn-offline-cancel')) { state.showOffline = false; render(); return; }

    const cp = target.closest('[data-copy]');
    if (cp) { copyText(cp.dataset.copy); return; }

    const shot = target.closest('[data-shot]');
    if (shot) { openShot(shot.dataset.shot); return; }

    const dtab = target.closest('[data-dtab]');
    if (dtab) { state.detailTab = dtab.dataset.dtab; refreshDetailBody(); return; }

    const pk = target.closest('[data-pick]');
    if (pk) {
      const key = pk.dataset.pick;
      state.pick[key] = pk.dataset.val;
      app.querySelectorAll(`[data-pick="${key}"]`).forEach((el) => el.classList.toggle('active', el === pk));
      refreshPicker(key);
      if (e.detail === 2) runPicker(key); // double-click spawns right away
      return;
    }
    const pr = target.closest('[data-pick-run]');
    if (pr) { runPicker(pr.dataset.pickRun); return; }

    const ply = target.closest('[data-player]');
    if (ply) {
      selectPlayer(Number(ply.dataset.player));
      app.querySelectorAll('[data-player]').forEach((el) => el.classList.toggle('selected', el === ply));
      refreshDetailBody();
      renderTargetChip();
      return;
    }

    const act = target.closest('[data-act]');
    if (act && act.tagName !== 'FORM') {
      const id = act.dataset.act;
      const extra = act.dataset.payload ? JSON.parse(act.dataset.payload) : {};
      if (act.dataset.toggle) {
        state.toggles[id] = !state.toggles[id];
        paintToggles();
      }
      run(id, extra);
    }
  });

  function runPicker(key) {
    const P = PICKERS[key];
    const val = state.pick[key];
    if (!val) return;
    const payload = {};
    payload[P.value === 'name' ? 'weapon' : 'model'] = val;
    if (P.frozen) payload.frozen = !!($(`pk-frozen-${key}`) && $(`pk-frozen-${key}`).checked);
    run(P.act, payload);
  }

  app.addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.target;
    if (!(form instanceof HTMLFormElement)) return;
    const id = form.dataset.act;
    if (!id) return;
    const payload = {};
    new FormData(form).forEach((v, k) => { payload[k] = typeof v === 'string' ? v.trim() : v; });
    if (id === 'tp.coords') {
      ['x', 'y', 'z', 'w'].forEach((k) => { payload[k] = Number(payload[k] || 0); });
      if ([payload.x, payload.y, payload.z].some((n) => Number.isNaN(n))) { toast('Coordinates must be numbers', 'error'); return; }
    }
    if (id === 'world.time') { payload.hour = Number(payload.hour); payload.minute = Number(payload.minute || 0); }
    if (id === 'veh.extras') payload.extra = Number(payload.extra);
    if (id === 'veh.livery') payload.livery = Number(payload.livery);
    if (id === 'veh.xenon') payload.color = Number(payload.color);
    if (id === 'veh.tint') payload.tint = Number(payload.tint);
    if (id === 'ply.bucket') payload.bucket = Number(payload.bucket);
    if (id === 'veh.plate' && payload.plate) payload.plate = payload.plate.toUpperCase();
    const textField = ['ply.message', 'ply.note', 'staff.announce', 'veh.save', 'tp.saveLocation', 'veh.plate'].includes(id);
    if (textField && !Object.values(payload).some((v) => String(v).length)) { toast('Type something first', 'warn'); return; }
    run(id, payload);
    // clear one-shot text inputs after sending
    if (['ply.message', 'ply.note', 'staff.announce', 'veh.save', 'tp.saveLocation'].includes(id)) {
      form.querySelectorAll('input:not([type=number]):not([type=hidden]), textarea').forEach((el) => { el.value = ''; });
      const cnt = $('announce-count');
      if (cnt && id === 'staff.announce') cnt.textContent = '0';
    }
  });

  // Coordinates paste helper: vector3(...), vector4(...), "x, y, z[, w]" or JSON {x,y,z}
  function parseCoords(text) {
    // ignore digits that are part of a word, e.g. the "3"/"4" in vector3/vector4
    const nums = String(text || '').match(/(?<![A-Za-z_\d.])-?\d+(?:\.\d+)?/g);
    if (!nums || nums.length < 3) return null;
    return nums.slice(0, 4).map(Number);
  }

  content.addEventListener('input', (e) => {
    if (e.target.matches && e.target.matches('input.range')) paintRange(e.target);
    const el = e.target;
    switch (el.id) {
      case 'f-players': state.filters.players = el.value; { const l = $('player-list'); if (l) l.innerHTML = playerRowsHtml(); } break;
      case 'f-bans': state.filters.bans = el.value; { const tb = $('ban-table'); if (tb) tb.innerHTML = banRowsHtml(); } break;
      case 'f-audit': state.filters.audit = el.value; { const tb = $('audit-table'); if (tb) tb.innerHTML = auditRowsHtml(); } break;
      case 'f-tp': state.filters.tp = el.value; { const g = $('tp-grid'); if (g) g.innerHTML = locationGridHtml(); } break;
      case 'f-res': state.filters.res = el.value; { const tb = $('res-table'); if (tb) tb.innerHTML = resourceRowsHtml(); } break;
      case 'announce-input': { const c = $('announce-count'); if (c) c.textContent = el.value.length; } break;
      case 'tp-paste': {
        const n = parseCoords(el.value);
        const form = content.querySelector('form[data-act="tp.coords"]');
        if (n && form) {
          ['x', 'y', 'z', 'w'].forEach((k, i) => { if (n[i] != null) form.elements[k].value = n[i]; });
        }
        break;
      }
      default:
        if (el.id && el.id.startsWith('pk-q-')) {
          const key = el.id.slice(5);
          state.pickQuery[key] = el.value;
          refreshPicker(key);
        }
        if (el.dataset && el.dataset.clock) {
          const form = el.form;
          const h = String(form.elements.hour.value).padStart(2, '0');
          const m = String(form.elements.minute.value).padStart(2, '0');
          const c = $('clock');
          if (c) c.textContent = `${h}:${m}`;
        }
    }
  });

  window.addEventListener('keydown', (e) => {
    if (!state.open) return;
    const k = e.key;
    if ((e.ctrlKey || e.metaKey) && (k === 'k' || k === 'K')) { e.preventDefault(); state.palette.open ? closePalette() : openPalette(); return; }
    if (k === 'Escape') {
      e.preventDefault();
      if (state.palette.open) closePalette();
      else if (!$('shot-view').classList.contains('hidden')) closeShot();
      else if (!modal.classList.contains('hidden')) modal.classList.add('hidden');
      else post('close', {});
      return;
    }
    if (state.palette.open) {
      const items = state.palette.items;
      if (k === 'ArrowDown') { state.palette.index = Math.min(items.length - 1, state.palette.index + 1); renderPalette(); e.preventDefault(); }
      if (k === 'ArrowUp') { state.palette.index = Math.max(0, state.palette.index - 1); renderPalette(); e.preventDefault(); }
      if (k === 'Enter') { activatePaletteItem(items[state.palette.index]); e.preventDefault(); }
      return;
    }
    // "/" opens the palette when not typing
    const typing = /^(INPUT|TEXTAREA|SELECT)$/.test((document.activeElement || {}).tagName || '');
    if (k === '/' && !typing && modal.classList.contains('hidden')) { e.preventDefault(); openPalette(); }
  });

  // ── Messages from Lua ──────────────────────────────────────────────────
  window.addEventListener('message', (event) => {
    const d = event.data || {};
    switch (d.type) {
      case 'open': {
        state.open = true;
        state.actions = d.actions || [];
        state.actionSet = new Set(state.actions.map((a) => a.id));
        state.players = d.players || [];
        state.bans = d.bans || [];
        state.resources = d.resources || [];
        state.aces = d.aces || [];
        state.locale = d.locale || {};
        state.config = d.config || {};
        state.vehicles = d.vehicles || [];
        state.weapons = d.weapons || [];
        state.props = d.props || [];
        state.peds = d.peds || [];
        state.world = d.world || {};
        state.audit = d.audit || [];
        state.savedVehicles = d.savedVehicles || [];
        state.savedLocations = d.savedLocations || [];
        state.lookupResult = null;
        state.toggles = {};
        mergeToggles(d.toggles || {});
        if (state.selectedPlayer) {
          state.selectedPlayer = state.players.find((p) => p.id === state.selectedPlayer.id) || null;
          state.playerRecord = null;
          if (state.selectedPlayer) post('playerRecord', { target: state.selectedPlayer.id });
        }
        // keep the last page if it's still allowed, otherwise the first visible one
        if (!sectionVisible(state.category)) {
          const first = SECTIONS.flatMap((g) => g.items).find((s) => sectionVisible(s.id));
          state.category = first ? first.id : 'staff';
        }
        app.classList.remove('hidden');
        render();
        scheduleRefresh();
        content.focus();
        break;
      }
      case 'close':
        state.open = false;
        app.classList.add('hidden');
        closePalette();
        modal.classList.add('hidden');
        if (state.refreshTimer) { clearInterval(state.refreshTimer); state.refreshTimer = null; }
        break;
      case 'toggles':
        state.toggles = {};
        mergeToggles(d.toggles || {});
        if (state.open) paintToggles();
        break;
      case 'players': {
        state.players = d.players || [];
        let lost = false;
        if (state.selectedPlayer) {
          const keep = state.selectedPlayer.id;
          state.selectedPlayer = state.players.find((p) => p.id === keep) || null;
          if (!state.selectedPlayer) { state.playerRecord = null; lost = true; }
        }
        if (state.open) refreshPlayersLive(lost);
        break;
      }
      case 'playerRecord': {
        const rec = d.record || {};
        if (state.selectedPlayer && rec.target === state.selectedPlayer.id) {
          state.playerRecord = rec;
          if (state.open && state.category === 'players') {
            // keep a half-typed note / message: only rebuild the header unless the body is idle
            const body = $('detail-body');
            const busy = body && Array.from(body.querySelectorAll('input:not([type=number]), textarea')).some((el) => el.value);
            if (busy) { const head = $('detail-head'); if (head) head.innerHTML = detailHeadHtml(state.selectedPlayer); }
            else refreshDetailBody();
          }
        }
        break;
      }
      case 'audit':
        state.audit = d.audit || [];
        if (state.open && state.category === 'audit') { const tb = $('audit-table'); if (tb) tb.innerHTML = auditRowsHtml(); else render(); }
        break;
      case 'lookup':
        state.lookupResult = d.lookup || {};
        if (state.open && state.category === 'bans') render();
        break;
      case 'bans':
        state.bans = d.bans || [];
        if (state.open) { if (state.category === 'bans') render(); else renderNav(); }
        break;
      case 'resources':
        state.resources = d.resources || [];
        if (state.open && state.category === 'staff') { const tb = $('res-table'); if (tb) tb.innerHTML = resourceRowsHtml(); }
        break;
      case 'world':
        state.world = d.world || {};
        if (typeof state.world.freeze === 'boolean') state.toggles['world.freezeTime'] = !!state.world.freeze;
        if (typeof state.world.blackout === 'boolean') state.toggles['world.blackout'] = !!state.world.blackout;
        if (state.open && state.category === 'world') render();
        else if (state.open) paintToggles();
        break;
      case 'savedVehicles':
        state.savedVehicles = d.vehicles || [];
        if (state.open && state.category === 'vehicles') render();
        break;
      case 'savedLocations':
        state.savedLocations = d.locations || [];
        if (state.open && state.category === 'teleport') render();
        break;
      case 'playerDropped':
        state.players = state.players.filter((p) => p.id !== d.id);
        if (state.selectedPlayer && state.selectedPlayer.id === d.id) {
          state.selectedPlayer = null;
          state.playerRecord = null;
          if (state.open) refreshPlayersLive(true);
        } else if (state.open) refreshPlayersLive(false);
        break;
      case 'shotImage': {
        const x = d.shot || {};
        if ($('shot-view').classList.contains('hidden') || String(x.id) !== String(state.shotId)) break;
        if (x.missing || typeof x.image !== 'string' || !x.image.startsWith('data:image/')) {
          $('shot-frame').innerHTML = empty('camera', 'This screenshot no longer exists.');
          break;
        }
        $('shot-title').textContent = `Screenshot of ${x.targetName || 'player'}`;
        $('shot-meta').textContent = `${fmtTs(x.created)} · by ${x.staffName || 'Staff'}`;
        const img = new Image();
        img.alt = 'Screenshot';
        img.src = x.image;
        $('shot-frame').replaceChildren(img);
        break;
      }
      case 'toast':
        toast(d.message, d.level, d.ms);
        break;
      case 'clipboard':
        copyText(d.text);
        break;
      case 'announce': {
        const box = $('announce');
        $('announce-author').textContent = d.author || 'Announcement';
        $('announce-msg').textContent = d.message || '';
        box.classList.remove('hidden');
        clearTimeout(box._t);
        box._t = setTimeout(() => box.classList.add('hidden'), 8000);
        break;
      }
      default:
        break;
    }
  });
})();
