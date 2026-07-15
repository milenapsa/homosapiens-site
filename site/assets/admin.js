(() => {
  'use strict';

  const API_BASE = window.HS_API_BASE || 'https://api.homosapiens.id/platform';
  const SESSION_KEY = 'hs_admin_session';
  let token = sessionStorage.getItem(SESSION_KEY);
  let oneTimeToken = null;
  let tokenTimer = null;

  const $ = (selector) => document.querySelector(selector);
  const views = {
    login: $('#login-view'),
    password: $('#password-view'),
    dashboard: $('#dashboard')
  };

  function showView(name) {
    Object.entries(views).forEach(([key, element]) => {
      element.hidden = key !== name;
    });
  }

  function setConnection(label, state = 'idle') {
    $('#connection-label').textContent = label;
    $('#connection-state').dataset.state = state;
  }

  function setMessage(selector, message = '', kind = '') {
    const element = $(selector);
    element.textContent = message;
    element.dataset.kind = kind;
  }

  function setBusy(button, busy, busyLabel) {
    if (!button.dataset.label) button.dataset.label = button.textContent;
    button.disabled = busy;
    button.textContent = busy ? busyLabel : button.dataset.label;
  }

  function endSession(message = '') {
    token = null;
    oneTimeToken = null;
    sessionStorage.removeItem(SESSION_KEY);
    clearTimeout(tokenTimer);
    showView('login');
    setConnection('Sessão não iniciada', 'idle');
    if (message) setMessage('#login-output', message, 'error');
  }

  async function request(path, options = {}) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 12000);
    const headers = new Headers(options.headers || {});
    headers.set('Content-Type', 'application/json');
    if (token) headers.set('Authorization', `Bearer ${token}`);

    try {
      const response = await fetch(`${API_BASE}${path}`, {...options, headers, signal: controller.signal});
      const contentType = response.headers.get('content-type') || '';
      const payload = contentType.includes('application/json')
        ? await response.json()
        : {detail: `Resposta HTTP ${response.status}`};

      if (response.status === 401) {
        endSession('A sessão expirou ou foi invalidada. Entre novamente.');
        throw Object.assign(new Error('Sessão inválida.'), {handled: true});
      }
      if (!response.ok) {
        throw Object.assign(new Error(payload.detail || 'Não foi possível concluir a operação.'), {status: response.status});
      }
      return payload;
    } catch (error) {
      if (error.name === 'AbortError') throw new Error('A operação excedeu o tempo limite.');
      throw error;
    } finally {
      clearTimeout(timeout);
    }
  }

  function formatDate(value) {
    if (!value) return 'Sem expiração';
    const data = new Date(value);
    return Number.isNaN(date.getTime()) ? String(value) : date.toLocaleString('pt-BR');
  }

  function statusBadge(value) {
    const span = document.createElement('span');
    span.className = `tag tag-${value || 'preview'}`;
    span.textContent = ({online:'online', preview:'prévia', maintenance:'manutenção', private:'privado'})[value] || value || 'prévia';
    return span;
  }

  function textCell(value) {
    const td = document.createElement('td');
    td.textContent = String(value ?? '—');
    return td;
  }

  function renderSummary(summary) {
    const labels = {
      products: 'Produtos',
      active_tokens: 'Tokens ativos',
      schemas: 'Schemas ativos',
      audit_events: 'Eventos de auditoria'
    };
    const grid = $('#summary');
    grid.replaceChildren();
    Object.entries(labels).forEach(([key, label]) => {
      const article = document.createElement('article');
      article.className = 'metric';
      const value = document.createElement('strong');
      value.textContent = String(summary[key] ?? 0);
      const name = document.createElement('span');
      name.textContent = label;
      article.append(value, name);
      grid.append(article);
    });
    $('#session-description').textContent = `Sessão ativa: ${summary.admin || 'administrador autorizado'}`;
  }

  function renderProducts(products) {
    const tbody = $('#products-table');
    tbody.replaceChildren();
    if (!products.length) {
      const row = document.createElement('tr');
      const cell = textCell('Nenhum produto cadastrado.');
      cell.colSpan = 5;
      row.append(cell);
      tbody.append(row);
      return;
    }
    products.forEach((product) => {
      const row = document.createElement('tr');
      const status = document.createElement('td');
      status.append(statusBadge(product.status));
      row.append(
        textCell(product.name),
        textCell(product.slug),
        status,
        textCell(product.public ? 'Sim' : 'Não'),
        textCell(product.sandbox_enabled ? 'Sim' : 'Não')
      );
      tbody.append(row);
    });
  }

  function renderTokens(tokens) {
    const tbody = $('#tokens-table');
    tbody.replaceChildren();
    if (!tokens.length) {
      const row = document.createElement('tr');
      const cell = textCell('Nenhum token cadastrado.');
      cell.colSpan = 6;
      row.append(cell);
      tbody.append(row);
      return;
    }
    tokens.forEach((item) => {
      const row = document.createElement('tr');
      const revoked = Boolean(item.revoked_at);
      const expired = item.expires_at && new Date(item.expires_at) <= new Date();
      const state = revoked ? 'Revogado' : expired ? 'Expirado' : 'Ativo';
      const action = document.createElement('td');
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'table-action';
      button.textContent = revoked ? 'Revogado' : 'Revogar';
      button.disabled = revoked;
      button.dataset.revokeToken = item.id;
      button.dataset.tokenName = item.name;
      action.append(button);
      row.append(
        textCell(item.name),
        textCell(item.prefix),
        textCell(item.scopes),
        textCell(formatDate(item.expires_at)),
        textCell(state),
        action
      );
      tbody.append(row);
    });
  }

  function renderAudit(events) {
    const list = $('#audit-list');
    list.replaceChildren();
    if (!events.length) {
      const item = document.createElement('li');
      item.textContent = 'Nenhum evento registrado.';
      list.append(item);
      return;
    }
    events.forEach((event) => {
      const item = document.createElement('li');
      const main = document.createElement('div');
      const action = document.createElement('strong');
      action.textContent = event.action;
      const target = document.createElement('span');
      target.textContent = event.target ? ` · ${event.target}` : '';
      main.append(action, target);
      const meta = document.createElement('small');
      meta.textContent = `${event.actor} · ${formatDate(event.created_at)}`;
      item.append(main, meta);
      list.append(item);
    });
  }

  async function loadDashboard() {
    if (!token) return endSession();
    setConnection('Consultando API administrativa…', 'loading');
    const refreshButton = $('#refresh');
    setBusy(refreshButton, true, 'Atualizando…');
    try {
      const [summary, products, tokens, audit] = await Promise.all([
        request('/v1/admin/summary'),
        request('/v1/admin/products'),
        request('/v1/admin/tokens'),
        request('/v1/admin/audit?limit=20')
      ]);
      renderSummary(summary);
      renderProducts(products);
      renderTokens(tokens);
      renderAudit(audit);
      showView('dashboard');
      setConnection('Sessão administrativa ativa', 'online');
      $('#last-update').textContent = `Atualizado em ${new Date().toLocaleTimeString('pt-BR')}`;
    } catch (error) {
      if (!error.handled) {
        setConnection('Falha ao consultar a API', 'error');
        setMessage('#login-output', error.message, 'error');
      }
    } finally {
      setBusy(refreshButton, false, 'Atualizando…');
    }
  }

  $('#login-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    const button = $('#login-submit');
    setMessage('#login-output');
    setBusy(button, true, 'Entrando…');
    try {
      const payload = await request('/v1/admin/login', {
        method: 'POST',
        body: JSON.stringify({
          email: $('#email').value.trim(),
          password: $('#password').value
        })
      });
      token = payload.access_token;
      sessionStorage.setItem(SESSION_KEY, token);
      $('#password').value = '';
      if (payload.must_change_password) {
        showView('password');
        setConnection('Troca de senha obrigatória', 'warning');
      } else {
        await loadDashboard();
      }
    } catch (error) {
      if (!error.handled) setMessage('#login-output', error.message, 'error');
    } finally {
      setBusy(button, false, 'Entrando…');
    }
  });

  $('#password-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    const button = $('#password-submit');
    const newPassword = $('#new-password').value;
    if (newPassword !== $('#confirm-password').value) {
      return setMessage('#password-output', 'A confirmação não coincide com a nova senha.', 'error');
    }
    setMessage('#password-output');
    setBusy(button, true, 'Atualizando…');
    try {
      await request('/v1/admin/password', {
        method: 'POST',
        body: JSON.stringify({
          current_password: $('#current-password').value,
          new_password: newPassword
        })
      });
      event.target.reset();
      setMessage('#password-output', 'Senha atualizada. Carregando o console…', 'success');
      await loadDashboard();
    } catch (error) {
      if (!error.handled) setMessage('#password-output', error.message, 'error');
    } finally {
      setBusy(button, false, 'Atualizando…');
    }
  });

  $('#password-cancel').addEventListener('click', () => endSession());
  $('#logout').addEventListener('click', () => endSession());
  $('#refresh').addEventListener('click', loadDashboard);

  $('#token-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    const button = $('#token-submit');
    setMessage('#token-output');
    if (!$('#token-confirm').checked) {
      return setMessage('#token-output', 'Confirme a revisão antes de emitir o token.', 'error');
    }
    const scopes = $('#token-scopes').value.split(/[\s,]+/).map((value) => value.trim()).filter(Boolean);
    const localExpiry = $('#token-expires').value;
    setBusy(button, true, 'Gerando…');
    try {
      const payload = await request('/v1/admin/tokens', {
        method: 'POST',
        body: JSON.stringify({
          name: $('#token-name').value.trim(),
          scopes,
          expires_at: localExpiry ? new Date(localExpiry).toISOString() : null
        })
      });
      oneTimeToken = payload.token;
      $('#token-result').hidden = false;
      $('#token-result-meta').textContent = `${payload.name} · prefixo ${payload.prefix} · ${payload.scopes.join(', ')}`;
      $('#token-expiry-note').textContent = 'O valor completo ficará disponível para cópia por 60 segundos e não será inserido no HTML.';
      $('#copy-token').disabled = false;
      clearTimeout(tokenTimer);
      tokenTimer = setTimeout(() => {
        oneTimeToken = null;
        $('#copy-token').disabled = true;
        $('#token-expiry-note').textContent = 'Janela de cópia encerrada.';
      }, 60000);
      event.target.reset();
      $('#token-scopes').value = 'read';
      await loadDashboard();
    } catch (error) {
      if (!error.handled) setMessage('#token-output', error.message, 'error');
    } finally {
      setBusy(button, false, 'Gerando…');
    }
  });

  $('#copy-token').addEventListener('click', async () => {
    if (!oneTimeToken) return setMessage('#token-output', 'O token não está mais disponível nesta sessão.', 'error');
    try {
      await navigator.clipboard.writeText(oneTimeToken);
      oneTimeToken = null;
      $('#copy-token').disabled = true;
      $('#token-expiry-note').textContent = 'Token copiado e removido da memória da tela.';
      setMessage('#token-output', 'Token copiado. Guarde-o em cofre autorizado.', 'success');
    } catch {
      setMessage('#token-output', 'O navegador bloqueou a área de transferência.', 'error');
    }
  });

  $('#product-form').addEventListener('submit', async (event) => {
    event.preventDefault();
    const button = $('#product-submit');
    setMessage('#product-output');
    setBusy(button, true, 'Cadastrando…');
    try {
      await request('/v1/admin/products', {
        method: 'POST',
        body: JSON.stringify({
          slug: $('#product-slug').value.trim().toLowerCase(),
          name: $('#product-name').value.trim(),
          description: $('#product-description').value.trim(),
          status: $('#product-status').value,
          public: $('#product-public').checked,
          sandbox_enabled: $('#product-sandbox').checked
        })
      });
      event.target.reset();
      $('#product-public').checked = true;
      $('#product-sandbox').checked = true;
      setMessage('#product-output', 'Produto cadastrado no catálogo administrativo.', 'success');
      await loadDashboard();
    } catch (error) {
      if (!error.handled) setMessage('#product-output', error.message, 'error');
    } finally {
      setBusy(button, false, 'Cadastrando…');
    }
  });

  $('#tokens-table').addEventListener('click', async (event) => {
    const id = event.target?.dataset?.revokeToken;
    if (!id) return;
    const name = event.target.dataset.tokenName || `#${id}`;
    if (!window.confirm(`Revogar o token "${name}"? Esta ação interrompe seu uso.`)) return;
    event.target.disabled = true;
    try {
      await request(`/v1/admin/tokens/${id}/revoke`, {method: 'POST'});
      await loadDashboard();
    } catch (error) {
      if (!error.handled) {
        event.target.disabled = false;
        window.alert(error.message);
      }
    }
  });

  if (token) loadDashboard();
  else showView('login');
})();
