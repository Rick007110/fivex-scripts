(() => {
  const root = document.getElementById('root');
  const App = window.FlexaApp; // Flexa App SDK

  const ICON = {
    map: '<path d="M1 6v16l7-4 8 4 7-4V2l-7 4-8-4z"/><path d="M8 2v16M16 6v16"/>',
    flag: '<path d="M4 22V4M4 4h13l-2 4 2 4H4"/>',
    pin: '<path d="M12 22s7-6.1 7-12a7 7 0 1 0-14 0c0 5.9 7 12 7 12z"/><circle cx="12" cy="10" r="2.5"/>',
    back: '<path d="m15 18-6-6 6-6"/>',
    check: '<path d="M5 12.5 10 17 19 7"/>',
    x: '<path d="M6 6l12 12M18 6 6 18"/>',
    chevron: '<path d="m9 18 6-6-6-6"/>',
  };
  const icon = (n) => `<svg viewBox="0 0 24 24">${ICON[n]}</svg>`;
  const VAN = `<svg class="van" viewBox="0 0 64 36"><path d="M4 26V12c0-3 2-5 5-5h30c3 0 5 1 7 3l8 8c3 1 6 3 6 6v2c0 1-1 2-2 2h-4"/><path d="M4 26c0 1 1 2 2 2h6M22 28h20"/><circle cx="17" cy="28" r="4.5"/><circle cx="47" cy="28" r="4.5"/><path d="M10 13h10v6H10zM24 13h12v6H24zM40 13h3l5 6h-8z"/><circle cx="30" cy="4" r="2"/></svg>`;

  const fmt = new Intl.NumberFormat('en-US');
  const money = (n) => '$' + fmt.format(Math.max(0, Math.floor(Number(n) || 0)));
  const km = (k) => (Number(k) || 0) < 1 ? `${Math.round((Number(k) || 0) * 1000 / 10) * 10} m` : `${(Number(k) || 0).toFixed(1)} km`;
  const dist = (m) => (m == null ? '—' : m >= 1000 ? `${(m / 1000).toFixed(1)} km` : `${Math.round(m / 10) * 10} m`);
  const eta = (s) => (s == null ? '—' : s < 60 ? '< 1 min' : `${Math.round(s / 60)} min`);
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const list = (x) => (Array.isArray(x) ? x : Object.values(x || {}));

  let data = null;    // state from Lua
  let ride = null;
  let live = {};
  let selected = null; // { kind, index?, label, area, km, fare }
  let busy = false;
  let cancelArmed = false;
  let visible = true;

  const ACTIVE = ['searching', 'dispatched', 'enroute', 'arrived', 'riding', 'dropoff', 'leaving'];
  const tooShort = (d) => d && d.km * 1000 / 1.3 < (data ? data.minTrip : 150);
  const canAfford = (fare) => data && (data.wallet.bank >= fare || data.wallet.cash >= fare);

  function load() {
    return App.post('state').then((d) => {
      if (!d || !d.places) return;
      data = d;
      data.places = list(d.places);
      ride = d.ride || null;
      live = d.live || {};
      if (d.fromMap && d.waypoint) selected = Object.assign({ kind: 'waypoint' }, d.waypoint);
      if (selected && selected.kind === 'waypoint' && d.waypoint) Object.assign(selected, d.waypoint);
      render();
    });
  }

  /* ---------- views ---------- */

  function header(back) {
    const w = data ? data.wallet : { bank: 0, cash: 0 };
    return `<div class="top">
      ${back ? `<button class="icon-btn" data-a="back" aria-label="Back">${icon('back')}</button>` : '<img src="logo.svg" alt="">'}
      <div class="brand grow">Kno<span>Way</span></div>
      <div class="wallet">Bank <b>${money(w.bank)}</b><br>Cash <b>${money(w.cash)}</b></div>
    </div>`;
  }

  function homeView() {
    const wp = data.waypoint;
    const wpRow = wp
      ? `<button class="item" data-a="pickWaypoint" ${tooShort(wp) ? 'disabled' : ''}>
          <span class="ico kw">${icon('flag')}</span>
          <span class="main"><div class="t">${esc(wp.label || 'Map waypoint')}</div><div class="s">Your map waypoint · ${esc(wp.area || '')}</div></span>
          <span class="side"><b>${money(wp.fare)}</b><span>${km(wp.km)}</span></span></button>`
      : '';
    const places = data.places.map((p) => `
      <button class="item" data-a="pickPlace" data-i="${p.index}" ${tooShort(p) ? 'disabled' : ''}>
        <span class="ico">${icon('pin')}</span>
        <span class="main"><div class="t">${esc(p.label)}</div><div class="s">${esc(p.area)}</div></span>
        <span class="side"><b>${money(p.fare)}</b><span>${km(p.km)}</span></span></button>`).join('');
    return `<div class="view">${header(false)}
      <div class="scroll">
        <h1>Where to?</h1>
        <button class="where" data-a="map"><span class="dot"></span><span class="grow">Pick on map</span><span class="pill">Map</span></button>
        ${wp ? `<div class="label">Waypoint</div><div class="list">${wpRow}</div>` : ''}
        <div class="label">Places</div>
        <div class="list">${places || '<div class="empty">No places configured.</div>'}</div>
        <div class="note">You are at ${esc(data.me.street || 'an unknown road')}, ${esc(data.me.area || '')}. A driverless KnoWay van picks you up here.</div>
      </div></div>`;
  }

  function confirmView() {
    const s = selected;
    const afford = canAfford(s.fare);
    return `<div class="view">${header(true)}
      <div class="scroll">
        <h1>Confirm ride</h1>
        <div class="route"><div class="line"></div>
          <div class="stop"><span class="mark"></span><div><div class="k">Pickup</div><div class="v">${esc(data.me.street || 'Your location')}</div><div class="a">${esc(data.me.area || '')}</div></div></div>
          <div class="stop to"><span class="mark"></span><div><div class="k">Drop-off</div><div class="v">${esc(s.label)}</div><div class="a">${esc(s.area || '')} · ${km(s.km)}</div></div></div>
        </div>
        <div class="ride-card">${VAN}
          <div class="main"><div class="t">KnoWay</div><div class="s">Driverless · up to 3 riders · back right door</div></div>
          <div class="fare">${money(s.fare)}</div></div>
        <div class="note">You pay when you press <b>Go</b> inside the van — bank first, then cash. Cancel before that and it's free. Cancel mid-trip and the unused distance is refunded.</div>
        ${afford ? '' : `<div class="note" style="color:var(--danger)">You need ${money(s.fare)} in your bank or cash.</div>`}
      </div>
      <div class="bottom"><button class="cta" data-a="book" ${busy || !afford ? 'disabled' : ''}>${busy ? 'Requesting…' : 'Request KnoWay'}</button></div></div>`;
  }

  const STEPS = [
    ['searching', 'Finding your van'],
    ['enroute', 'On the way to you'],
    ['arrived', 'Waiting at pickup'],
    ['riding', 'On trip'],
    ['dropoff', 'Arrived'],
  ];
  const stepIndex = (st) => ({ searching: 0, dispatched: 0, enroute: 1, arrived: 2, riding: 3, dropoff: 4, leaving: 4 }[st] ?? 0);

  function liveView() {
    const st = ride.state;
    const i = stepIndex(st);
    const titles = {
      searching: ['Finding your KnoWay', 'Matching you with a nearby van'],
      dispatched: ['Van assigned', 'It is setting off towards you'],
      enroute: ['On the way', 'Watch for the white KnoWay van'],
      arrived: ['Your KnoWay is here', 'Get in through the back right door, then press Go'],
      riding: [`Heading to ${ride.dest ? ride.dest.label : ''}`, 'Sit back — KnoWay is driving'],
      dropoff: ['You have arrived', 'Please get out of the van'],
      leaving: ['Thanks for riding', 'The van is heading off'],
    }[st] || ['KnoWay', ''];
    const showEta = st === 'enroute' || st === 'riding';
    const steps = STEPS.map(([, label], n) =>
      `<div class="step ${n < i ? 'done' : n === i ? 'now' : ''}"><i>${n < i ? icon('check') : ''}</i>${esc(label)}</div>`).join('');
    const canCancel = ['searching', 'dispatched', 'enroute', 'arrived', 'riding'].includes(st);
    const cancelText = cancelArmed ? (st === 'riding' ? 'Tap again — stop & refund the rest' : 'Tap again to cancel') : 'Cancel ride';
    return `<div class="view">${header(false)}
      <div class="scroll">
        <div class="hero">
          <div class="radar"><img src="logo.svg" alt=""></div>
          <div class="t">${esc(titles[0])}</div>
          <div class="s">${esc(titles[1])}</div>
          ${showEta ? `<div class="eta"><div><b>${eta(live.eta)}</b><span>ETA</span></div><div><b>${dist(live.dist)}</b><span>${st === 'riding' ? 'To go' : 'Away'}</span></div></div>` : ''}
          ${['enroute', 'arrived'].includes(st) ? `<div style="margin-top:12px;color:var(--muted);font-size:13px">${esc(ride.vehicleLabel || 'KnoWay')} · <span class="plate">${esc(ride.plate || 'KNOWAY')}</span></div>` : ''}
        </div>
        <div class="steps">${steps}</div>
        <div class="route" style="margin-top:12px"><div class="stop to"><span class="mark"></span><div><div class="k">Drop-off</div><div class="v">${esc(ride.dest ? ride.dest.label : '')}</div><div class="a">${esc(ride.dest ? ride.dest.area : '')} · ${money(ride.fare)}</div></div></div></div>
      </div>
      ${canCancel ? `<div class="bottom"><button class="cta ghost" data-a="cancel">${cancelText}</button></div>` : ''}</div>`;
  }

  function receiptView() {
    const ok = ride.state === 'complete';
    const charged = (ride.paid || 0) - (ride.refund || 0);
    const why = { no_show: 'You did not get in, so the van left. No charge.', vehicle_failed: 'No van could reach you. No charge.', user: ok ? 'You ended the trip early.' : 'You cancelled. No charge.' }[ride.reason] || '';
    return `<div class="view">${header(false)}
      <div class="scroll">
        <div class="check ${ok ? '' : 'bad'}">${icon(ok ? 'check' : 'x')}</div>
        <div class="hero"><div class="t">${ok ? 'Ride complete' : 'Ride cancelled'}</div><div class="s">${esc(why || (ok ? 'Thanks for riding KnoWay.' : ''))}</div></div>
        <div class="rows">
          <div class="row"><span>Destination</span><b>${esc(ride.dest ? ride.dest.label : '—')}</b></div>
          <div class="row"><span>Distance</span><b>${km(ride.km)}</b></div>
          ${ride.paid ? `<div class="row"><span>Fare</span><b>${money(ride.paid)}</b></div>` : ''}
          ${ride.refund ? `<div class="row"><span>Refund</span><b>−${money(ride.refund)}</b></div>` : ''}
          <div class="row total"><span>Charged</span><b>${money(charged)}</b></div>
        </div>
      </div>
      <div class="bottom"><button class="cta" data-a="done">Done</button></div></div>`;
  }

  // Patch `a` in place to match `b`: unchanged nodes stay put, so nothing flickers or restarts animating.
  function morph(a, b) {
    if (a.nodeType !== b.nodeType || a.nodeName !== b.nodeName) {
      a.replaceWith(b.cloneNode(true));
      return;
    }
    if (a.nodeType === Node.TEXT_NODE) {
      if (a.nodeValue !== b.nodeValue) a.nodeValue = b.nodeValue;
      return;
    }
    if (a.nodeType !== Node.ELEMENT_NODE) return;
    for (const { name } of [...a.attributes]) if (!b.hasAttribute(name)) a.removeAttribute(name);
    for (const { name, value } of [...b.attributes]) if (a.getAttribute(name) !== value) a.setAttribute(name, value);
    if ('disabled' in a && a.disabled !== b.hasAttribute('disabled')) a.disabled = b.hasAttribute('disabled');
    const ac = [...a.childNodes];
    const bc = [...b.childNodes];
    bc.forEach((n, i) => { if (i < ac.length) morph(ac[i], n); else a.appendChild(n.cloneNode(true)); });
    for (let i = ac.length - 1; i >= bc.length; i--) ac[i].remove();
  }

  let lastHtml = '';
  let lastView = '';

  function render() {
    let html;
    let view;
    if (!data) { view = 'loading'; html = `<div class="view">${header(false)}<div class="scroll"><div class="empty">Loading…</div></div></div>`; }
    else if (ride && ACTIVE.includes(ride.state)) { view = 'live'; html = liveView(); }
    else if (ride && (ride.state === 'complete' || ride.state === 'cancelled')) { view = 'receipt'; html = receiptView(); }
    else if (selected) { view = 'confirm'; html = confirmView(); }
    else { view = 'home'; html = homeView(); }

    if (html === lastHtml) return; // nothing changed: leave the DOM alone
    lastHtml = html;
    if (view === lastView && root.firstElementChild) {
      const tpl = document.createElement('template');
      tpl.innerHTML = html;
      morph(root.firstElementChild, tpl.content.firstElementChild);
      return;
    }
    lastView = view; // new screen: replace and let the entry animation play
    root.innerHTML = html;
  }

  /* ---------- actions ---------- */

  root.addEventListener('click', (e) => {
    const b = e.target.closest('[data-a]');
    if (!b || b.disabled) return;
    const a = b.dataset.a;
    if (a !== 'cancel') cancelArmed = false;
    if (a === 'map') {
      App.post('pickOnMap');
    } else if (a === 'pickWaypoint') {
      selected = Object.assign({ kind: 'waypoint' }, data.waypoint);
      render();
    } else if (a === 'pickPlace') {
      const p = data.places.find((x) => String(x.index) === b.dataset.i);
      if (p) { selected = Object.assign({ kind: 'place' }, p); render(); }
    } else if (a === 'back') {
      selected = null;
      render();
    } else if (a === 'book') {
      busy = true;
      render();
      const payload = selected.kind === 'place' ? { kind: 'place', index: selected.index } : { kind: 'waypoint' };
      App.post('book', payload).then((res) => {
        busy = false;
        if (!res || !res.ok) {
          App.toast(res && res.error === 'no_waypoint' ? 'Your waypoint is gone — pick again' : 'Could not request a ride');
          render();
          return;
        }
        selected = null;
        setTimeout(load, 400);
      });
    } else if (a === 'cancel') {
      if (!cancelArmed) { cancelArmed = true; render(); setTimeout(() => { if (cancelArmed) { cancelArmed = false; render(); } }, 4000); return; }
      cancelArmed = false;
      App.post('cancel');
    } else if (a === 'done') {
      App.post('dismiss').then(load);
    }
  });

  /* ---------- SDK wiring ---------- */

  App.on('init', () => { render(); load(); });
  App.on('message', (m) => {
    if (!m || m.type !== 'ride') return;
    ride = m.ride || null;
    live = m.live || {};
    if (!ride || !ACTIVE.includes(ride.state)) cancelArmed = false;
    if (data) render(); else load();
  });
  App.on('visibility', (v) => { visible = v; if (v) load(); });

  // keep waypoint / prices fresh while choosing
  setInterval(() => { if (visible && (!ride || !ACTIVE.includes(ride.state))) load(); }, 3000);

  render();
  load();
})();
