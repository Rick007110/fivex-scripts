(() => {
  const resource = (typeof GetParentResourceName === 'function')
    ? GetParentResourceName()
    : 'fivex_jobcenter';

  const $ = (id) => document.getElementById(id);
  const app = $('app');
  const jobsEl = $('jobs');
  const modal = $('modal');
  const toasts = $('toasts');

  let state = {
    open: false,
    job: false,
    jobLabel: 'Unemployed',
    balance: 0,
    duty: false,
    jobs: [],
  };

  function post(name, data) {
    return fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({ ok: false }));
  }

  function toast(message, level) {
    const el = document.createElement('div');
    el.className = 'toast ' + (level || 'info');
    el.textContent = message || '';
    toasts.appendChild(el);
    setTimeout(() => el.remove(), 4200);
  }

  function render() {
    $('cur-job').textContent = state.jobLabel || 'Unemployed';
    $('cur-pay').textContent = '$' + String(state.balance || 0);
    $('cur-duty').textContent = state.job
      ? (state.duty ? 'On duty at the workplace' : 'Off duty — clock in at your workplace')
      : 'Apply below. One job at a time.';

    const leave = $('btn-leave');
    if (state.job) leave.classList.remove('hidden');
    else leave.classList.add('hidden');

    jobsEl.innerHTML = '';
    (state.jobs || []).forEach((job) => {
      const card = document.createElement('article');
      card.className = 'job-card card';
      const hired = state.job === job.id;
      card.innerHTML = `
        <h3>${escapeHtml(job.label)}</h3>
        <p>${escapeHtml(job.blurb)}</p>
        <button type="button" class="btn ${hired ? '' : 'primary'} block" data-id="${escapeAttr(job.id)}" ${hired ? 'disabled' : ''}>
          ${hired ? 'Hired' : 'Apply'}
        </button>`;
      const btn = card.querySelector('button');
      btn.addEventListener('click', () => {
        if (hired || btn.disabled) return;
        btn.disabled = true;
        post('apply', { id: job.id }).then((res) => {
          if (!res || !res.ok) btn.disabled = false;
        }).catch(() => { btn.disabled = false; });
      });
      jobsEl.appendChild(card);
    });
  }

  function escapeHtml(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }
  function escapeAttr(s) { return escapeHtml(s).replace(/`/g, ''); }

  function openUi(payload) {
    state = Object.assign(state, payload || {});
    state.open = true;
    app.classList.remove('hidden');
    modal.classList.add('hidden');
    render();
  }

  function closeUi() {
    state.open = false;
    app.classList.add('hidden');
    modal.classList.add('hidden');
    post('close', {});
  }

  $('btn-close').addEventListener('click', closeUi);
  $('btn-leave').addEventListener('click', () => {
    $('modal-body').textContent = state.jobLabel
      ? `Leave ${state.jobLabel}? You will clock off immediately.`
      : 'Leave your current job?';
    modal.classList.remove('hidden');
  });
  $('modal-cancel').addEventListener('click', () => modal.classList.add('hidden'));
  $('modal-form').addEventListener('submit', (e) => {
    e.preventDefault();
    modal.classList.add('hidden');
    post('leave', {});
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      if (!modal.classList.contains('hidden')) {
        modal.classList.add('hidden');
        return;
      }
      if (state.open) closeUi();
    }
  });


  const CIRC = 2 * Math.PI * 42;

  function setProgress(d) {
    const el = $('work-progress');
    if (!el) return;
    const hide = d.hide === true || d.pct === false || d.pct === null || d.pct === undefined;
    if (hide) {
      el.classList.add('hidden');
      el.setAttribute('aria-hidden', 'true');
      return;
    }
    let n = Number(d.pct);
    if (!Number.isFinite(n)) {
      el.classList.add('hidden');
      el.setAttribute('aria-hidden', 'true');
      return;
    }
    if (n > 1) n = n / 100;
    n = Math.max(0, Math.min(1, n));
    const arc = $('work-progress-arc');
    if (arc) arc.style.strokeDasharray = (n * CIRC).toFixed(3) + ' ' + CIRC.toFixed(3);
    const pctEl = $('work-progress-pct');
    if (pctEl) pctEl.textContent = Math.round(n * 100) + '%';
    const lab = $('work-progress-label');
    if (lab) {
      const text = (d.label == null || d.label === '') ? 'Working' : String(d.label);
      lab.textContent = text;
    }
    el.classList.remove('hidden');
    el.setAttribute('aria-hidden', 'false');
  }

  window.addEventListener('message', (event) => {
    const d = event.data || {};
    if (d.type === 'progress') {
      setProgress(d);
    } else if (d.type === 'open') openUi(d);
    else if (d.type === 'close') {
      state.open = false;
      app.classList.add('hidden');
      modal.classList.add('hidden');
    } else if (d.type === 'state') {
      state = Object.assign(state, d);
      if (state.open) render();
    } else if (d.type === 'toast') {
      toast(d.message, d.level);
    }
  });
})();
