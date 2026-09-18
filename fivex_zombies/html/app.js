(() => {
  const $ = (id) => document.getElementById(id);
  const overlay = $('overlay');
  const frame = $('frame');
  const eyebrow = $('eyebrow');
  const titleEl = $('title');
  const subtitleEl = $('subtitle');
  const graceWrap = $('grace-wrap');
  const graceEl = $('grace');

  let hideTimer = null;
  let graceTimer = null;
  let alarm = null;
  let alarmLoopTimer = null;

  const DEFAULTS = {
    start: {
      title: 'APOCALYPSE',
      subtitle: 'All civs infected — prepare',
      eyebrow: 'FIVEX · EVENT',
      durationMs: 9000,
    },
    stop: {
      title: 'ALL CLEAR',
      subtitle: 'Streets returning to normal',
      eyebrow: 'FIVEX · EVENT',
      durationMs: 8000,
    },
  };

  function clearTimers() {
    if (hideTimer) {
      window.clearTimeout(hideTimer);
      hideTimer = null;
    }
    if (graceTimer) {
      window.clearInterval(graceTimer);
      graceTimer = null;
    }
  }

  function hideOverlay() {
    clearTimers();
    overlay.classList.remove('is-in');
    window.setTimeout(() => {
      if (!overlay.classList.contains('is-in')) {
        overlay.classList.add('hidden');
        frame.classList.remove('kind-start', 'kind-stop');
        graceWrap.classList.add('hidden');
      }
    }, 240);
  }

  function showAnnounce(msg) {
    const kind = msg.kind === 'stop' ? 'stop' : 'start';
    const def = DEFAULTS[kind];
    const title = String(msg.title || def.title);
    const subtitle = String(msg.subtitle || def.subtitle);
    const durationMs = Number(msg.durationMs);
    const showMs = Number.isFinite(durationMs) && durationMs > 0 ? durationMs : def.durationMs;

    clearTimers();
    frame.classList.remove('kind-start', 'kind-stop');
    frame.classList.add(kind === 'start' ? 'kind-start' : 'kind-stop');
    eyebrow.textContent = def.eyebrow;
    titleEl.textContent = title;
    subtitleEl.textContent = subtitle;

    let grace = Number(msg.grace);
    if (kind === 'start' && Number.isFinite(grace) && grace > 0) {
      grace = Math.floor(grace);
      graceEl.textContent = String(grace);
      graceWrap.classList.remove('hidden');
      graceTimer = window.setInterval(() => {
        grace -= 1;
        if (grace <= 0) {
          graceEl.textContent = '0';
          window.clearInterval(graceTimer);
          graceTimer = null;
          return;
        }
        graceEl.textContent = String(grace);
      }, 1000);
    } else {
      graceWrap.classList.add('hidden');
    }

    overlay.classList.remove('hidden');
    // force reflow for fade-in
    void overlay.offsetWidth;
    overlay.classList.add('is-in');

    hideTimer = window.setTimeout(hideOverlay, showMs);
  }

  function stopAlarm() {
    if (alarmLoopTimer) {
      window.clearInterval(alarmLoopTimer);
      alarmLoopTimer = null;
    }
    if (alarm) {
      try {
        alarm.pause();
        alarm.currentTime = 0;
      } catch (_) {}
      alarm = null;
    }
  }

  function safeSrc(src) {
    const n = String(src || 'audio/alarm.ogg').trim();
    if (!n || n.indexOf('..') !== -1) return '';
    if (/^[a-z][a-z0-9+.-]*:/i.test(n)) return '';
    return n.replace(/^\/+/, '');
  }

  function playAlarm(msg) {
    stopAlarm();
    const src = safeSrc(msg.src || 'audio/alarm.ogg');
    if (!src) return;

    const el = new Audio();
    const vol = Number(msg.volume);
    el.volume = Number.isFinite(vol) ? Math.min(1, Math.max(0, vol)) : 0.5;
    el.preload = 'auto';
    el.src = src;

    const loopMs = Number(msg.loopMs);
    const playOnce = () => {
      el.currentTime = 0;
      el.play().catch(() => {});
    };

    el.addEventListener('error', () => {
      // Missing alarm.ogg is fine — hook stays ready when asset lands
      stopAlarm();
    });

    alarm = el;
    playOnce();

    if (Number.isFinite(loopMs) && loopMs > 0) {
      alarmLoopTimer = window.setInterval(playOnce, loopMs);
    } else {
      el.loop = true;
    }
  }

  window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'announce') {
      showAnnounce(d);
      return;
    }
    if (d.action === 'playAlarm') {
      playAlarm(d);
      return;
    }
    if (d.action === 'stopAlarm') {
      stopAlarm();
    }
  });
})();
