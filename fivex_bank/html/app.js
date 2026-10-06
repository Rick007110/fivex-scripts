(() => {
  const resource = (typeof GetParentResourceName === 'function')
    ? GetParentResourceName()
    : 'fivex_bank';

  const $ = (id) => document.getElementById(id);
  const app = $('app');
  const modal = $('modal');
  const toasts = $('toasts');
  const fmt = new Intl.NumberFormat('en-US');
  const money = (n) => (n < 0 ? '-$' : '$') + fmt.format(Math.abs(Math.floor(Number(n) || 0)));

  const KIND = {
    open: 'Account opened',
    deposit: 'Cash deposit',
    withdraw: 'Cash withdrawal',
    transfer_in: 'Transfer received',
    transfer_out: 'Transfer sent',
    income: 'Payment received',
    purchase: 'Purchase',
    refund: 'Refund',
    staff: 'Adjustment',
  };
  const CHIPS = [100, 500, 1000, 5000];

  let state = {
    open: false, mode: 'branch', location: '', account: '', name: '',
    balance: 0, cash: 0, history: [], limits: { withdraw: 0, deposit: 0, transfer: 0 },
  };
  let busy = false;

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

  function escapeHtml(s) {
    return String(s ?? '').replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  function when(t) {
    const d = new Date((Number(t) || 0) * 1000);
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' }) + ' ' +
      d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
  }

  function renderLimits() {
    const l = state.limits || {};
    const atm = state.mode === 'atm';
    $('cash-limit').textContent = atm
      ? `ATM limit: ${money(l.withdraw)} withdraw · ${money(l.deposit)} deposit per transaction`
      : '';
    const canTransfer = (l.transfer || 0) > 0;
    $('btn-transfer').disabled = busy || !canTransfer;
    $('tr-limit').textContent = !canTransfer
      ? 'Transfers are only available at a teller.'
      : (atm ? `ATM limit: ${money(l.transfer)} per transfer` : '');
  }

  function setBusy(on) {
    busy = on;
    $('btn-deposit').disabled = on;
    $('btn-withdraw').disabled = on;
    renderLimits();
  }

  function renderHistory() {
    const el = $('history');
    const list = state.history || [];
    if (!list.length) {
      el.innerHTML = '<div class="empty">No transactions yet.</div>';
      return;
    }
    el.innerHTML = list.map((tx) => {
      const a = Number(tx.a) || 0;
      return `<div class="tx">
        <div>
          <div class="tx-label">${escapeHtml(KIND[tx.k] || tx.k)}</div>
          <div class="tx-note">${escapeHtml(when(tx.t))}${tx.n ? ' · ' + escapeHtml(tx.n) : ''}</div>
        </div>
        <div>
          <div class="tx-amt ${a >= 0 ? 'in' : 'out'}">${a >= 0 ? '+' : ''}${money(a)}</div>
          <div class="tx-bal">${money(tx.b)}</div>
        </div>
      </div>`;
    }).join('');
  }

  function render() {
    $('location').textContent = state.location || '';
    $('bal').textContent = money(state.balance);
    $('cash').textContent = money(state.cash);
    $('acct').textContent = state.account || '—';
    $('holder').textContent = state.name || '';
    renderLimits();
    renderHistory();
  }

  function selectTab(name) {
    document.querySelectorAll('.tab').forEach((t) => {
      t.setAttribute('aria-selected', t.dataset.tab === name ? 'true' : 'false');
    });
    document.querySelectorAll('.panel').forEach((p) => {
      p.classList.toggle('hidden', p.dataset.panel !== name);
    });
  }

  function amountOf(id) {
    const n = Math.floor(Number($(id).value));
    return Number.isFinite(n) && n > 0 ? n : 0;
  }

  function accountOf() {
    return $('tr-account').value.trim().toUpperCase().replace(/\s+/g, '');
  }

  function act(name, data, onOk) {
    if (busy) return;
    setBusy(true);
    post(name, data).then((res) => {
      setBusy(false);
      if (res && res.ok && onOk) onOk();
    });
  }

  function clearInputs(ids) {
    ids.forEach((id) => { $(id).value = ''; });
  }

  function openUi(payload) {
    state = Object.assign(state, payload || {});
    state.open = true;
    app.classList.remove('hidden');
    modal.classList.add('hidden');
    clearInputs(['cash-amount', 'tr-account', 'tr-amount', 'tr-note']);
    selectTab('cash');
    setBusy(false);
    render();
  }

  function closeUi() {
    state.open = false;
    app.classList.add('hidden');
    modal.classList.add('hidden');
    post('close', {});
  }

  function addChip(label, value) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'chip';
    b.textContent = label;
    b.addEventListener('click', () => { $('cash-amount').value = Math.max(0, Math.floor(value() || 0)); });
    $('cash-chips').appendChild(b);
  }
  CHIPS.forEach((v) => addChip(money(v), () => v));
  addChip('All cash', () => state.cash);
  addChip('All bank', () => state.balance);

  document.querySelectorAll('.tab').forEach((t) => t.addEventListener('click', () => selectTab(t.dataset.tab)));

  $('btn-close').addEventListener('click', closeUi);

  $('btn-deposit').addEventListener('click', () => {
    const amount = amountOf('cash-amount');
    if (!amount) return toast('Enter a valid amount.', 'error');
    act('deposit', { amount }, () => clearInputs(['cash-amount']));
  });

  $('btn-withdraw').addEventListener('click', () => {
    const amount = amountOf('cash-amount');
    if (!amount) return toast('Enter a valid amount.', 'error');
    act('withdraw', { amount }, () => clearInputs(['cash-amount']));
  });

  $('btn-transfer').addEventListener('click', () => {
    const account = accountOf();
    const amount = amountOf('tr-amount');
    if (!/^FX\d{6}$/.test(account)) return toast('Account numbers look like FX123456.', 'error');
    if (!amount) return toast('Enter a valid amount.', 'error');
    if (account === state.account) return toast('You cannot transfer to your own account.', 'error');
    $('modal-body').textContent = `Send ${money(amount)} to ${account}? Transfers cannot be reversed.`;
    modal.classList.remove('hidden');
  });

  $('modal-cancel').addEventListener('click', () => modal.classList.add('hidden'));
  $('modal-form').addEventListener('submit', (e) => {
    e.preventDefault();
    modal.classList.add('hidden');
    act('transfer', {
      account: accountOf(),
      amount: amountOf('tr-amount'),
      note: $('tr-note').value.trim(),
    }, () => clearInputs(['tr-account', 'tr-amount', 'tr-note']));
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

  window.addEventListener('message', (event) => {
    const d = event.data || {};
    if (d.type === 'open') openUi(d);
    else if (d.type === 'close') {
      state.open = false;
      app.classList.add('hidden');
      modal.classList.add('hidden');
    } else if (d.type === 'state') {
      state = Object.assign(state, d);
      if (state.open) render();
    } else if (d.type === 'balance') {
      state.balance = d.balance;
      if (state.open) render();
    } else if (d.type === 'toast') {
      toast(d.message, d.level);
    }
  });
})();
