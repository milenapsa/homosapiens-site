const API_BASE = window.HS_API_BASE || 'https://api.homosapiens.id/platform';

const fallback = [
  {slug:'lex-juridica',name:'Lex Jurídica',description:'Pesquisa jurídica assistida com fontes públicas e respostas rastreáveis.',status:'preview'},
  {slug:'lex-search-core',name:'Lex Search Core',description:'Roteamento e agregação de fontes jurídicas públicas.',status:'online'},
  {slug:'lex-memory',name:'Lex Memory',description:'Memória operacional controlada para aplicações inteligentes.',status:'preview'},
  {slug:'datajud-connector',name:'DataJud Connector',description:'Consulta segura de metadados processuais públicos.',status:'preview'}
];

const grid = document.querySelector('#api-grid');

function text(value) {
  return document.createTextNode(String(value ?? ''));
}

function render(items) {
  grid.replaceChildren();

  for (const item of items) {
    const article = document.createElement('article');
    article.className = 'card';

    const tag = document.createElement('span');
    tag.className = 'tag';
    tag.appendChild(text(item.status || 'preview'));

    const title = document.createElement('h3');
    title.appendChild(text(item.name));

    const description = document.createElement('p');
    description.appendChild(text(item.description));

    const link = document.createElement('a');
    link.className = 'secondary';
    link.href = '#sandbox';
    link.dataset.product = item.slug;
    link.appendChild(text('Testar API'));

    article.append(tag, title, description, link);
    grid.appendChild(article);
  }
}

fetch(`${API_BASE}/v1/catalog`)
  .then((response) => response.ok ? response.json() : Promise.reject(new Error('catalog_unavailable')))
  .then(render)
  .catch(() => render(fallback));

document.addEventListener('click', (event) => {
  const product = event.target?.dataset?.product;
  if (product) {
    document.querySelector('#sandbox-product').value = product;
  }
});

document.querySelector('#sandbox-form').addEventListener('submit', async (event) => {
  event.preventDefault();

  const output = document.querySelector('#sandbox-output');
  output.textContent = 'Executando...';

  const body = {
    product_slug: document.querySelector('#sandbox-product').value,
    operation: document.querySelector('#sandbox-operation').value,
    query: document.querySelector('#sandbox-query').value
  };

  try {
    const response = await fetch(`${API_BASE}/v1/sandbox`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(body)
    });

    const payload = await response.json();
    output.textContent = JSON.stringify(payload, null, 2);
  } catch {
    output.textContent = JSON.stringify({
      sandbox: true,
      status: 'preview',
      message: 'Sandbox público será ativado junto com a API Platform.'
    }, null, 2);
  }
});
