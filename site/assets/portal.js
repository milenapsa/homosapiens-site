(() => {
  'use strict';

  const API_BASE = window.HS_API_BASE || 'https://api.homosapiens.id/platform';
  const fallback = [
    {slug:'lex-juridica', name:'Lex Jurídica', description:'Pesquisa jurídica assistida com fontes públicas e respostas rastreáveis.', status:'preview', endpoints:[]},
    {slug:'lex-search-core', name:'Lex Search Core', description:'Roteamento e agregação de fontes jurídicas públicas.', status:'online', endpoints:[]},
    {slug:'lex-memory', name:'Lex Memory', description:'Memória operacional controlada para aplicações inteligentes.', status:'preview', endpoints:[]},
    {slug:'datajud-connector', name:'DataJud Connector', description:'Consulta segura de metadados processuais públicos.', status:'preview', endpoints:[]}
  ];

  const $ = (selector) => document.querySelector(selector);
  const grid = $('#api-grid');
  const status = $('#platform-status');
  const form = $('#sandbox-form');
  const submit = $('#sandbox-submit');
  const result = $('#sandbox-result');

  function node(tag, className, value) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (value !== undefined) element.textContent = String(value);
    return element;
  }

  function statusLabel(value) {
    return ({online:'online', preview:'prévia', maintenance:'manutenção', private:'privado'})[value] || 'prévia';
  }

  function renderCatalog(items, source) {
    grid.replaceChildren();
    items.forEach((item) => {
      const article = node('article', 'card api-card');
      const top = node('div', 'card-top');
      const tag = node('span', `tag tag-${item.status || 'preview'}`, statusLabel(item.status));
      const endpoints = node('span', 'endpoint-count', `${(item.endpoints || []).length} endpoint(s)`);
      top.append(tag, endpoints);
      const title = node('h3', '', item.name);
      const description = node('p', '', item.description);
      const link = node('a', 'secondary', 'Testar API');
      link.href = '#sandbox';
      link.dataset.product = item.slug;
      article.append(top, title, description, link);
      grid.appendChild(article);
    });

    status.classList.toggle('status-preview', source !== 'api');
    status.innerHTML = '';
    status.append(node('span', '', ''), document.createTextNode(
      source === 'api'
        ? 'Catálogo público respondeu. Isso não comprova publicação produtiva completa.'
        : 'Prévia local carregada; a API pública não respondeu.'
    ));
  }

  async function request(path, options = {}) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    try {
      const response = await fetch(`${API_BASE}${path}`, {...options, signal: controller.signal});
      const contentType = response.headers.get('content-type') || '';
      const payload = contentType.includes('application/json')
        ? await response.json()
        : {detail: `Resposta HTTP ${response.status}`};
      if (!response.ok) throw Object.assign(new Error(payload.detail || 'Falha na solicitação.'), {status: response.status});
      return payload;
    } finally {
      clearTimeout(timeout);
    }
  }

  function renderSandbox(payload) {
    result.replaceChildren();
    const heading = node('div', 'result-heading');
    heading.append(node('strong', '', payload.sandbox ? 'Resposta demonstrativa' : 'Resposta'));
    if (payload.result?.trace_id) heading.append(node('code', '', payload.result.trace_id));
    result.append(heading);

    const summary = node('dl', 'result-list');
    const values = {
      Produto: payload.product,
      Operação: payload.operation,
      Estado: payload.result?.status,
      Mensagem: payload.result?.message
    };
    Object.entries(values).forEach(([key, value]) => {
      if (value === undefined || value === null) return;
      summary.append(node('dt', '', key), node('dd', '', value));
    });
    result.append(summary);
  }

  document.addEventListener('click', (event) => {
    const product = event.target?.dataset?.product;
    if (product) $('#sandbox-product').value = product;
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    submit.disabled = true;
    submit.textContent = 'Executando…';
    result.replaceChildren(node('p', 'muted', 'Executando demonstração segura…'));

    const body = {
      product_slug: $('#sandbox-product').value,
      operation: $('#sandbox-operation').value,
      query: $('#sandbox-query').value.trim()
    };

    try {
      renderSandbox(await request('/v1/sandbox', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body)
      }));
    } catch (error) {
      result.replaceChildren(
        node('strong', '', 'Sandbox indisponível'),
        node('p', 'muted', error.name === 'AbortError'
          ? 'A solicitação excedeu o tempo limite.'
          : 'A prévia não acessou sistemas autenticados. Tente novamente mais tarde.')
      );
    } finally {
      submit.disabled = false;
      submit.textContent = 'Executar teste';
    }
  });

  request('/v1/catalog')
    .then((items) => renderCatalog(Array.isArray(items) ? items : fallback, 'api'))
    .catch(() => renderCatalog(fallback, 'fallback'));
})();
