// Harbor Authority NUI
(function () {
  'use strict';

  const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'fivex_marina';
  const $ = (id) => document.getElementById(id);

  const ICONS = {
    sponge: '<path d="M4 8h16v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/><path d="M8 8V6a4 4 0 0 1 8 0v2"/><circle cx="9" cy="13" r="1"/><circle cx="14" cy="15" r="1"/>',
    fuel: '<path d="M5 21V6a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v15"/><path d="M3 21h14"/><path d="M15 9h2a2 2 0 0 1 2 2v5a1.5 1.5 0 0 0 3 0V8l-3-3"/><path d="M8 9h4"/>',
    anchor: '<circle cx="12" cy="5" r="2"/><path d="M12 7v14"/><path d="M5 12H2a10 10 0 0 0 20 0h-3"/><path d="M8 11h8"/>',
    net: '<path d="M3 4l18 0"/><path d="M5 4l3 16M19 4l-3 16M12 4v16"/><path d="M4 9h16M5 14h14M7 19h10"/>',
    ticket: '<path d="M3 8a2 2 0 0 0 0 4v4a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-4a2 2 0 0 1 0-4V6a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2z"/><path d="M13 4v16" stroke-dasharray="2 2"/>',
    lifebuoy: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/><path d="M5.6 5.6l3.6 3.6M14.8 14.8l3.6 3.6M18.4 5.6l-3.6 3.6M9.2 14.8l-3.6 3.6"/>',
  };

  const state = {
    board: null,
    profile: null,
    contract: null,
    tab: 'contracts',
    boardAt: 0,
  };

  function post(name, data) {
    return fetch(`https://${RES}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(() => {});
  }

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }
  const money = (n) => '$' + Math.round(Number(n) || 0).toLocaleString('en-US');
  function clock(ms) {
    const s = Math.max(0, Math.ceil(ms / 1000));
    return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
  }
  function xpFrac(p) {
    if (!p) return 0;
    if (p.nextXp == null) return 1;
    return Math.max(0, Math.min(1, (p.xp - p.rankXp) / (p.nextXp - p.rankXp)));
  }

  // ── HUD ────────────────────────────────────────────────
  function renderHud(d) {
    const hud = $('hud');
    if (!d.show) { hud.classList.add('hidden'); return; }
    hud.classList.remove('hidden');
    if (d.profile) state.profile = d.profile;
    const p = state.profile;
    if (p) {
      $('hud-rank').textContent = p.rankName;
      $('hud-xp').style.width = (xpFrac(p) * 100).toFixed(1) + '%';
      const st = $('hud-streak');
      if (p.streak > 0) {
        st.textContent = `🔥 ${p.streak}  +${Math.round(p.streakBonus * 100)}%`;
        st.classList.remove('hidden');
      } else st.classList.add('hidden');
    }
    const c = d.contract;
    if (!c) {
      state.contract = null;
      $('hud-card').classList.add('hidden');
      $('hud-idle').classList.remove('hidden');
      return;
    }
    state.contract = Object.assign({}, c, { receivedAt: performance.now() });
    $('hud-idle').classList.add('hidden');
    $('hud-card').classList.remove('hidden');
    $('hud-title').textContent = c.label;
    $('hud-area').textContent = c.areaLabel || '';
    $('hud-pay').textContent = '~' + money(c.pay * (1 + ((p && p.streakBonus) || 0)));
    $('hud-steps').innerHTML = (c.steps || []).map((s) =>
      `<li class="${s.done ? 'done' : ''} ${s.active && !s.done ? 'active' : ''}">${esc(s.text)}</li>`).join('');
    const stars = $('hud-stars');
    if (c.stars != null) {
      stars.classList.remove('hidden');
      let h = '';
      for (let i = 1; i <= 5; i++) h += i <= c.stars ? '★' : '<span class="off">★</span>';
      stars.innerHTML = h;
    } else stars.classList.add('hidden');
    tickHud();
  }

  function tickHud() {
    const c = state.contract;
    if (!c) return;
    const since = performance.now() - c.receivedAt;
    const left = c.endsIn - since;
    const elapsed = c.elapsed + since;
    const t = $('hud-timer');
    t.textContent = clock(left);
    t.classList.toggle('warn', left < 60000);
    $('hud-express').classList.toggle('gone', elapsed > c.par * 1000);
  }
  setInterval(tickHud, 250);

  // ── Gauge ──────────────────────────────────────────────
  const gauge = { perfect: 0.92, ok: 0.75, spill: 1.08 };
  const SCALE = 1.15; // track shows 0..115%
  function renderGauge(d) {
    const g = $('gauge');
    if (!d.show) { g.classList.add('hidden'); g.className = 'gauge hidden'; return; }
    if (d.perfect) { gauge.perfect = d.perfect; gauge.ok = d.ok; gauge.spill = d.spill; }
    g.classList.remove('hidden');
    const pct = (v) => (Math.min(v, SCALE) / SCALE * 100) + '%';
    $('g-ok').style.left = pct(gauge.ok);
    $('g-ok').style.width = `calc(${pct(gauge.perfect)} - ${pct(gauge.ok)})`;
    $('g-perfect').style.left = pct(gauge.perfect);
    $('g-perfect').style.width = `calc(${pct(1.0)} - ${pct(gauge.perfect)})`;
    $('g-spill').style.left = pct(gauge.spill);
    const v = Number(d.value) || 0;
    $('g-fill').style.width = pct(v);
    $('g-needle').style.left = `calc(${pct(v)} - 1px)`;
    $('g-value').textContent = Math.round(v * 100) + '%';
    g.classList.remove('result-perfect', 'result-ok', 'result-bad');
    if (d.done) {
      if (v >= gauge.spill || v < gauge.ok) g.classList.add('result-bad');
      else if (v >= gauge.perfect) g.classList.add('result-perfect');
      else g.classList.add('result-ok');
    }
  }

  // ── Toasts ─────────────────────────────────────────────
  let toastTimer = null;
  function showToast(html, fail, ms) {
    const t = $('toast');
    t.className = 'toast' + (fail ? ' fail' : '');
    t.innerHTML = html;
    // restart animation
    void t.offsetWidth;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.add('hidden'), ms || 6500);
  }

  function countUp(el, to, ms) {
    const start = performance.now();
    function step(now) {
      const f = Math.min(1, (now - start) / ms);
      const e = 1 - Math.pow(1 - f, 3);
      el.textContent = money(to * e);
      if (f < 1) requestAnimationFrame(step);
    }
    requestAnimationFrame(step);
  }

  function renderCompleted(d) {
    const rows = [];
    let delay = 0;
    const row = (label, val, cls) => {
      rows.push(`<div class="row ${cls || ''}" style="animation-delay:${delay}ms"><span>${esc(label)}</span><b>${esc(val)}</b></div>`);
      delay += 140;
    };
    row('Contract rate', money(d.base));
    if (d.qualityLabel) {
      const q = Math.round((d.quality - 1) * 100);
      row(d.qualityLabel, (q >= 0 ? '+' : '') + q + '%', q > 0 ? 'plus' : (q < 0 ? 'minus' : ''));
    }
    if (d.streakBonus > 0) row('Streak bonus', '+' + Math.round(d.streakBonus * 100) + '%', 'plus');
    if (d.express) row(`Express (${clock(d.elapsed * 1000)} / par ${clock(d.par * 1000)})`, '+20%', 'plus');
    rows.push(`<div class="row total" style="animation-delay:${delay}ms"><span>Paid</span><b id="toast-total">$0</b></div>`);
    const p = d.profile;
    showToast(
      `<div class="toast-kicker">CONTRACT COMPLETE</div>
       <div class="toast-title">${esc(d.label)}</div>
       <div class="rows">${rows.join('')}</div>
       <div class="xpline"><span>+${d.xpGain} XP</span><span>${esc(p.rankName)}${p.nextName ? ' → ' + esc(p.nextName) : ''}</span></div>
       <div class="xpbar"><span id="toast-xp" style="width:0"></span></div>`,
      false, 7500);
    setTimeout(() => {
      const el = $('toast-total');
      if (el) countUp(el, d.pay, 900);
      const xb = $('toast-xp');
      if (xb) xb.style.width = (xpFrac(p) * 100).toFixed(1) + '%';
    }, delay);
    state.profile = p;
    if (d.rankUp) {
      setTimeout(() => {
        $('promo-rank').textContent = d.rankUp.name;
        $('promo-sub').textContent = `Pay rate ×${Number(d.rankUp.pay).toFixed(2)} · Work boat: ${d.rankUp.boatLabel}`;
        const pr = $('promo');
        pr.classList.remove('hidden');
        void pr.offsetWidth;
        setTimeout(() => pr.classList.add('hidden'), 5200);
      }, 1500);
    }
  }

  function renderFailed(d) {
    showToast(
      `<div class="toast-kicker">CONTRACT FAILED</div>
       <div class="toast-title">${esc(d.label)}</div>
       <div class="muted">${esc(d.reason)} · streak reset</div>`,
      true, 5000);
  }

  // ── Tablet ─────────────────────────────────────────────
  function setTab(tab) {
    state.tab = tab;
    document.querySelectorAll('.tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
    $('view-contracts').classList.toggle('hidden', tab !== 'contracts');
    $('view-career').classList.toggle('hidden', tab !== 'career');
    $('view-board').classList.toggle('hidden', tab !== 'board');
  }

  function renderOffers(b) {
    const activeKind = b.active;
    $('active-banner').classList.toggle('hidden', !activeKind);
    if (activeKind) {
      const off = (b.offers || []).find((o) => o.kind === activeKind);
      $('active-label').textContent = off ? off.label : 'Contract';
    }
    $('offers').innerHTML = (b.offers || []).map((o, i) => {
      const locked = o.locked;
      const isCurrent = activeKind === o.kind;
      const btn = locked
        ? `<span class="lock-tag">🔒 ${esc(o.rankName)}</span>`
        : `<button type="button" class="btn primary" data-accept="${esc(o.id)}" ${activeKind ? 'disabled' : ''}>Accept</button>`;
      return `<div class="card ${locked ? 'locked' : ''} ${isCurrent ? 'current' : ''}" style="animation-delay:${i * 45}ms">
          <div class="card-top">
            <div class="ico"><svg viewBox="0 0 24 24">${ICONS[o.icon] || ICONS.anchor}</svg></div>
            <div><div class="card-title">${esc(o.label)}</div><div class="card-area">${esc(o.areaLabel || '')}</div></div>
          </div>
          <div class="card-blurb">${esc(o.blurb)}</div>
          <div class="card-stats">
            <span class="pill"><b>+${o.xp}</b> XP</span>
            <span class="pill">Par <b>${clock(o.par * 1000)}</b></span>
            <span class="pill">Limit <b>${clock(o.limit * 1000)}</b></span>
          </div>
          <div class="card-foot"><div class="card-pay">${money(o.pay)}</div>${btn}</div>
        </div>`;
    }).join('');
  }

  function renderCareer(p) {
    if (!p) return;
    $('c-badge').textContent = p.rank;
    $('c-rank').textContent = p.rankName;
    $('c-xp').style.width = (xpFrac(p) * 100).toFixed(1) + '%';
    $('c-xptext').textContent = p.nextXp != null
      ? `${p.xp.toLocaleString()} / ${p.nextXp.toLocaleString()} XP to ${p.nextName}`
      : `${p.xp.toLocaleString()} XP · top rank reached`;
    $('c-mult').textContent = '×' + Number(p.payMult).toFixed(2);
    $('c-jobs').textContent = p.jobs.toLocaleString();
    $('c-earned').textContent = money(p.earned);
    $('c-best').textContent = p.best;
    $('c-boat').textContent = p.boatLabel;
    $('c-ladder').innerHTML = (p.ranks || []).map((r, i) => {
      const n = i + 1;
      const cls = n === p.rank ? 'current' : (n < p.rank ? 'reached' : '');
      return `<div class="rung ${cls}"><div class="r-name">${esc(r.name)}</div>
        <div class="r-meta">${r.xp.toLocaleString()} XP · ×${Number(r.pay).toFixed(2)}</div>
        <div class="r-meta">${esc(r.boatLabel)}</div></div>`;
    }).join('');
  }

  function renderLeaderboard(list) {
    const rows = $('lb-rows');
    if (!list || !list.length) {
      rows.innerHTML = '<div class="lb-empty">No captains on the board yet. Be the first.</div>';
      return;
    }
    rows.innerHTML = list.map((e, i) => `<div class="lb-row ${e.me ? 'me' : ''}" style="animation-delay:${i * 40}ms">
        <span class="pos">${i + 1}</span><span>${esc(e.name)}</span><span class="muted">${esc(e.rank)}</span>
        <span>${Number(e.jobs).toLocaleString()}</span><span class="money">${money(e.earned)}</span></div>`).join('');
  }

  function renderBoard(b) {
    state.board = b;
    state.boardAt = performance.now();
    state.profile = b.profile || state.profile;
    renderOffers(b);
    renderCareer(b.profile);
    renderLeaderboard(b.leaderboard);
    $('shift-earned').textContent = money(b.shift ? b.shift.earned : 0);
  }

  setInterval(() => {
    const b = state.board;
    if (!b) return;
    const left = b.refreshIn - (performance.now() - state.boardAt);
    $('refresh-in').textContent = left > 0 ? `New contracts in ${clock(left)}` : 'New contracts available — reopen the tablet';
  }, 500);

  function openTablet(open) {
    $('tablet').classList.toggle('hidden', !open);
    if (open) setTab(state.tab);
  }

  // ── Summary ────────────────────────────────────────────
  function renderSummary(d) {
    $('s-time').textContent = d.minutes + 'm';
    $('s-jobs').textContent = d.jobs;
    $('s-earned').textContent = money(d.earned);
    $('s-xp').textContent = '+' + d.xp;
    $('s-streak').textContent = d.bestStreak;
    $('s-fails').textContent = d.fails;
    const p = d.profile;
    $('s-xpbar').style.width = '0';
    setTimeout(() => { $('s-xpbar').style.width = (xpFrac(p) * 100).toFixed(1) + '%'; }, 200);
    $('s-rank').textContent = p.nextXp != null
      ? `${p.rankName} · ${p.nextXp - p.xp} XP to ${p.nextName}`
      : `${p.rankName} · top rank`;
    $('summary').classList.remove('hidden');
  }

  // ── Wiring ─────────────────────────────────────────────
  document.querySelectorAll('.tab').forEach((b) => b.addEventListener('click', () => setTab(b.dataset.tab)));
  $('btn-close').addEventListener('click', () => post('close'));
  $('btn-cancel').addEventListener('click', () => post('cancelContract'));
  $('btn-boat').addEventListener('click', () => post('requestBoat'));
  $('btn-summary').addEventListener('click', () => {
    $('summary').classList.add('hidden');
    post('closeSummary');
  });
  $('offers').addEventListener('click', (e) => {
    const btn = e.target.closest('[data-accept]');
    if (!btn || btn.disabled) return;
    btn.disabled = true;
    post('accept', { id: btn.getAttribute('data-accept') });
    post('close');
  });
  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('summary').classList.contains('hidden')) {
      $('summary').classList.add('hidden');
      post('closeSummary');
    } else if (!$('tablet').classList.contains('hidden')) {
      post('close');
    }
  });

  window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    switch (d.action) {
      case 'hud': renderHud(d); break;
      case 'gauge': renderGauge(d); break;
      case 'board': renderBoard(d.data || {}); break;
      case 'tablet': openTablet(!!d.open); break;
      case 'completed': renderCompleted(d.data || {}); break;
      case 'failed': renderFailed(d.data || {}); break;
      case 'summary': renderSummary(d.data || {}); break;
      default: break;
    }
  });

  post('ready');
})();
