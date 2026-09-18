(() => {
  const hud = document.getElementById('hud');
  const turfName = document.getElementById('turfName');
  const hint = document.getElementById('hint');
  const heatFill = document.getElementById('heatFill');
  const heatPct = document.getElementById('heatPct');
  const waveNum = document.getElementById('waveNum');
  const killNum = document.getElementById('killNum');

  function clamp(n, a, b) {
    return Math.max(a, Math.min(b, n));
  }

  function apply(data) {
    if (typeof data.turf === 'string' && data.turf) {
      turfName.textContent = data.turf;
    }
    if (typeof data.hint === 'string') {
      hint.textContent = data.hint;
    }
    if (typeof data.heat === 'number') {
      const h = clamp(data.heat, 0, 100);
      heatFill.style.width = h.toFixed(1) + '%';
      heatPct.textContent = Math.round(h) + '%';
    }
    if (typeof data.wave === 'number') {
      waveNum.textContent = String(data.wave);
    }
    if (typeof data.kills === 'number') {
      killNum.textContent = String(data.kills);
    }
  }

  window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'show') {
      hud.classList.remove('hidden');
      hud.setAttribute('aria-hidden', 'false');
      apply(data);
    } else if (data.action === 'hide') {
      hud.classList.add('hidden');
      hud.setAttribute('aria-hidden', 'true');
    } else if (data.action === 'update') {
      apply(data);
    }
  });
})();
