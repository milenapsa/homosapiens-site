const API_BASE = window.HS_API_BASE || 'https://api.homosapiens.id/platform';
const fallback = [
  {slug:'lex-juridica',name:'Lex Jurídica',description:'Pesquisa jurídica assistida com fontes públicas e respostas rastriáveis.',status:'preview'},
  {slug:'lex-search-core',name:'Lex Search Core',description:'Roteamento e agregação de fontes jurídicas públicas.',status:'online'},
  {slug:'lex-memory',name:'Lex Memory',description:'Memória operacional controlada para aplicações inteligentes.',status:'preview'},
  {slug:'datajud-connector',name:'DataJud Connector',description:'Consulta segura de metadados processuais públicos.',status:'preview'}
];
const grid=document.querySelector('#api-grid');
function render(items){grid.innerHTML=items.map(x=>`<article class="card"><span class="tag">${x.status||'preview'}</span><h3>${x.name}</h3><p>${x.description}</p><a class="secondary" href="#sandbox" data-product="${x.slug}">Testar API</a></article>`).join('')}
fetch(`${API_BASE}/v1/catalog`).then(r=>r.ok?r.json():Promise.reject()).then(render).catch(()=>render(fallback));
document.addEventListener('click',e=>{const p=e.target.dataset?.product;if(p){document.querySelector('#sandbox-product').value=p}});
document.querySelector('#sandbox-form').addEventListener('submit',async e=>{
 e.preventDefault();const out=document.querySelector('#sandbox-output');out.textContent='Executando...';
 const body={product_slug:document.querySelector('#sandbox-product').value,operation:document.querySelector('#sandbox-operation').value,query:document.querySelector('#sandbox-query').value};
 try{const r=await fetch(`${API_BASE}/v1/sandbox`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});out.textContent=JSON.stringify(await r.json(),null,2)}
 catch{out.textContent=JSON.stringify({sandbox:true,status:'preview',message:'Sandbox público será ativado junto com a API Platform.'},null,2)}
});