(() => {
  const $ = (id) => document.getElementById(id);

  // ── helpers ──────────────────────────────────────────
  const setText = (el, value) => {
    const v = String(value);
    if (el.textContent !== v) el.textContent = v;
  };
  const clock = (secs) => {
    secs = Math.max(0, Math.floor(secs || 0));
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    const s = String(secs % 60).padStart(2, '0');
    return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${s}` : `${m}:${s}`;
  };
  function show(el) {
    el.classList.remove('hidden');
    void el.offsetWidth; // reflow so the fade-in runs
    el.classList.add('is-in');
  }
  function hide(el, after) {
    el.classList.remove('is-in');
    window.setTimeout(() => {
      if (!el.classList.contains('is-in')) {
        el.classList.add('hidden');
        if (after) after();
      }
    }, 280);
  }

  // ── takeover ─────────────────────────────────────────
  const alert = $('alert');
  const RING = 326.73;
  let alertTimer = null;
  let countTimer = null;

  const DEFAULTS = {
    start: {
      eyebrow: 'Emergency Alert System',
      title: 'Outbreak',
      subtitle: 'Los Santos is infected. Find cover, gunfire draws them in.',
      ticker: 'THIS IS NOT A TEST · STAY INDOORS · AVOID GUNFIRE · HEADSHOTS KILL',
      durationMs: 9000,
    },
    stop: {
      eyebrow: 'Emergency Alert System',
      title: 'All clear',
      subtitle: 'The outbreak is contained. Streets are returning to normal.',
      ticker: 'OUTBREAK CONTAINED · STREETS REOPENING · STAY SAFE',
      durationMs: 9000,
    },
  };

  function clearAlertTimers() {
    window.clearTimeout(alertTimer);
    window.clearInterval(countTimer);
    alertTimer = countTimer = null;
  }

  function announce(msg) {
    const kind = msg.kind === 'stop' ? 'stop' : 'start';
    const def = DEFAULTS[kind];
    clearAlertTimers();

    alert.classList.remove('kind-start', 'kind-stop');
    alert.classList.add(`kind-${kind}`);
    setText($('alert-eyebrow'), msg.eyebrow || def.eyebrow);
    const title = String(msg.title || def.title);
    setText($('alert-title'), title);
    $('alert-title').setAttribute('data-text', title);
    setText($('alert-sub'), msg.subtitle || def.subtitle);

    // ticker text repeated so the marquee never runs dry
    const tick = String(msg.ticker || def.ticker);
    setText($('ticker'), Array(4).fill(tick).join('   ·   '));

    // start: grace countdown ring
    const countdown = $('countdown');
    let grace = Math.floor(Number(msg.grace));
    if (kind === 'start' && grace > 0) {
      const total = grace;
      const fill = $('ring-fill');
      fill.style.transition = 'none';
      fill.style.strokeDashoffset = '0';
      void fill.offsetWidth;
      fill.style.transition = '';
      setText($('count'), grace);
      countdown.classList.remove('hidden');
      countTimer = window.setInterval(() => {
        grace = Math.max(0, grace - 1);
        setText($('count'), grace);
        fill.style.strokeDashoffset = String(RING * (1 - grace / total));
        if (grace <= 0) window.clearInterval(countTimer);
      }, 1000);
    } else {
      countdown.classList.add('hidden');
    }

    // stop: what you did
    const summary = $('summary');
    if (kind === 'stop' && (msg.kills != null || msg.survived != null)) {
      setText($('sum-kills'), Number(msg.kills) || 0);
      setText($('sum-time'), clock(msg.survived));
      summary.classList.remove('hidden');
    } else {
      summary.classList.add('hidden');
    }

    show(alert);
    const ms = Number(msg.durationMs) > 0 ? Number(msg.durationMs) : def.durationMs;
    alertTimer = window.setTimeout(() => hide(alert, clearAlertTimers), ms);
  }

  // ── HUD ──────────────────────────────────────────────
  const hud = $('hud');
  const THREAT = ['Calm', 'Stirring', 'Hunted', 'Swarmed', 'Overrun'];
  let hudShown = false;
  let since = 0;
  let cloudAt = 0;   // cloud time (s) when the last update arrived
  let localAt = 0;   // Date.now() at that moment
  let pipCount = -1;
  let clockTimer = null;

  function threatLevel(nearby, hunting) {
    if (hunting >= 8 || nearby >= 22) return 4;
    if (hunting >= 4 || nearby >= 14) return 3;
    if (hunting >= 1) return 2;
    if (nearby >= 1) return 1;
    return 0;
  }

  function tickClock() {
    if (!since || !cloudAt) return;
    const now = cloudAt + (Date.now() - localAt) / 1000;
    setText($('hud-time'), clock(now - since));
  }

  function bumpIfUp(el, value) {
    const prev = Number(el.textContent) || 0;
    setText(el, value);
    if (value > prev) {
      el.classList.remove('bump');
      void el.offsetWidth;
      el.classList.add('bump');
    }
  }

  function updateHud(d) {
    if (!d.show) {
      if (hudShown) {
        hudShown = false;
        hide(hud);
        window.clearInterval(clockTimer);
        clockTimer = null;
      }
      return;
    }

    since = Number(d.since) || 0;
    cloudAt = Number(d.now) || 0;
    localAt = Date.now();

    const nearby = Number(d.nearby) || 0;
    const hunting = Number(d.hunting) || 0;
    bumpIfUp($('hud-nearby'), nearby);
    bumpIfUp($('hud-hunting'), hunting);
    bumpIfUp($('hud-kills'), Number(d.kills) || 0);

    const lvl = threatLevel(nearby, hunting);
    const threat = $('threat');
    if (threat.dataset.level !== String(lvl)) threat.dataset.level = String(lvl);
    setText($('threat-val'), THREAT[lvl]);

    // infection pips, rebuilt only when the maximum changes
    const max = Math.max(1, Number(d.infectMax) || 5);
    const hits = Math.min(max, Number(d.infect) || 0);
    const pips = $('pips');
    if (pipCount !== max) {
      pipCount = max;
      pips.textContent = '';
      for (let i = 0; i < max; i++) pips.appendChild(document.createElement('i'));
    }
    Array.from(pips.children).forEach((p, i) => p.classList.toggle('on', i < hits));

    const turned = !!d.turned;
    hud.classList.toggle('is-turned', turned);
    $('infect').classList.toggle('is-high', !turned && hits >= max - 1 && hits > 0);
    setText($('hud-name'), turned ? 'Turned' : 'Outbreak');
    setText($('infect-key'), turned ? 'Infected' : 'Infection');
    setText($('infect-val'), turned ? 'Melee only' : `${hits}/${max}`);

    $('night').classList.toggle('hidden', !d.night || turned);

    tickClock();
    if (!hudShown) {
      hudShown = true;
      show(hud);
      clockTimer = window.setInterval(tickClock, 1000);
    }
  }

  // ── horde toast ──────────────────────────────────────
  const toast = $('toast');
  let toastTimer = null;

  function horde(d) {
    window.clearTimeout(toastTimer);
    setText($('toast-title'), d.title || 'Horde inbound');
    setText($('toast-sub'), d.text || '');
    const n = Number(d.size) || 0;
    $('toast-count').classList.toggle('hidden', n <= 0);
    setText($('toast-count'), n);
    // sits left of the HUD when it is up, in the corner when not
    toast.style.right = hudShown ? '292px' : '28px';
    show(toast);
    toastTimer = window.setTimeout(() => hide(toast), 6500);
  }

  // ── alarm ────────────────────────────────────────────
  let alarm = null;

  function stopAlarm() {
    if (!alarm) return;
    try {
      alarm.pause();
      alarm.currentTime = 0;
    } catch (_) {}
    alarm = null;
  }

  function safeSrc(src) {
    const n = String(src || 'audio/alarm.ogg').trim();
    if (!n || n.indexOf('..') !== -1) return '';
    if (/^[a-z][a-z0-9+.-]*:/i.test(n)) return '';
    return n.replace(/^\/+/, '');
  }

  function playAlarm(msg) {
    stopAlarm();
    const src = safeSrc(msg.src);
    if (!src) return;
    const el = new Audio();
    const vol = Number(msg.volume);
    el.volume = Number.isFinite(vol) ? Math.min(1, Math.max(0, vol)) : 0.5;
    el.loop = true;
    el.src = src;
    el.addEventListener('error', stopAlarm);
    alarm = el;
    el.play().catch(() => {});
  }

  window.addEventListener('message', (e) => {
    const d = e.data || {};
    switch (d.action) {
      case 'announce': announce(d); break;
      case 'hud': updateHud(d); break;
      case 'horde': horde(d); break;
      case 'playAlarm': playAlarm(d); break;
      case 'stopAlarm': stopAlarm(); break;
    }
  });
})();
