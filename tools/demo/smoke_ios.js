// Teste curto no WebKit (motor do Safari) com perfil de iPhone, no link publicado.
// Requer playwright-core e o WebKit do Playwright:
//   set PLAYWRIGHT_BROWSERS_PATH=<pasta> && node node_modules/playwright-core/cli.js install webkit
//   node tools/demo/smoke_ios.js
// Variaveis opcionais: BASE (URL) e OUT (pasta das capturas).
const { webkit, devices } = require('playwright-core');
const fs = require('fs');
const path = require('path');

const BASE = process.env.BASE || 'https://draraiany-source.github.io/pediatria360-demo/';
const OUT = process.env.OUT || path.join(require('os').tmpdir(), 'p360-ios');
fs.mkdirSync(OUT, { recursive: true });
const results = [];
const pageErrors = [];
function check(name, ok, detail) {
  results.push(!!ok);
  console.log((ok ? 'OK   ' : 'FALHA') + ' ' + name + (detail ? ' -> ' + detail : ''));
}
const hash = (page) => new URL(page.url()).hash.split('?')[0];

async function labels(page) {
  return page.evaluate(() => [...document.querySelectorAll('flt-semantics-host *')]
    .map((e) => [e.getAttribute('aria-label') || '', e.children.length ? '' : (e.textContent || '')].join(' ').trim())
    .filter(Boolean).join(' | ').replace(/\s+/g, ' '));
}
async function waitText(page, text, timeout = 10000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    if ((await labels(page)).includes(text)) return true;
    await page.waitForTimeout(400);
  }
  return false;
}
async function find(page, label) {
  return page.evaluate((label) => {
    const els = [...document.querySelectorAll('flt-semantics')].filter((e) => ['button', 'link', 'tab'].includes(e.getAttribute('role')) || e.hasAttribute('flt-tappable'));
    const text = (e) => (e.getAttribute('aria-label') || e.textContent || '').replace(/\s+/g, ' ').trim();
    const el = els.find((e) => text(e).startsWith(label));
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, label);
}
async function tap(page, label, wait = 2000) {
  for (let i = 0; i < 12; i++) {
    const b = await find(page, label);
    if (b && b.y > 20 && b.y < 844 - 120) { await page.touchscreen.tap(b.x, b.y); await page.waitForTimeout(wait); return true; }
    await page.evaluate((dy) => { const s = [...document.querySelectorAll('flt-semantics')].find((e) => e.scrollHeight > e.clientHeight + 20 && getComputedStyle(e).overflowY !== 'visible'); if (s) s.scrollTop += dy; }, b ? b.y - 400 : 500);
    await page.waitForTimeout(600);
  }
  throw new Error('nao encontrado: ' + label);
}
async function open(page, route) {
  await page.goto(BASE + route);
  await page.waitForFunction(() => document.getElementById('loading')?.classList.contains('hidden'), null, { timeout: 90000 });
  await page.waitForTimeout(1500);
  const ph = await page.evaluate(() => { const p = document.querySelector('flt-semantics-placeholder'); if (!p) return null; const r = p.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; });
  if (ph) { await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await page.waitForTimeout(800); }
  if (!(await page.evaluate(() => document.querySelectorAll('flt-semantics-host *').length))) {
    if (ph) await page.touchscreen.tap(Math.max(1, ph.x), Math.max(1, ph.y));
    await page.waitForTimeout(1500);
  }
}
async function step(name, fn) {
  try { await fn(); } catch (e) { check(name, false, String(e.message || e).slice(0, 200)); }
}

(async () => {
  const browser = await webkit.launch();
  const ctx = await browser.newContext({ ...devices['iPhone 15'], locale: 'pt-BR' });
  const page = await ctx.newPage();
  page.on('pageerror', (e) => pageErrors.push(String(e).slice(0, 200)));

  await step('iphone: abre o link publicado', async () => {
    await open(page, '');
    const n = await page.evaluate(() => document.querySelectorAll('flt-semantics-host *').length);
    check('iphone: carrega e liga a leitura da tela', n > 0, n + ' nos');
    check('iphone: aviso de demonstracao', await waitText(page, 'DEMONSTRA'), '');
    await page.screenshot({ path: path.join(OUT, 'ios01_inicio.png') });
  });

  await step('iphone: familia', async () => {
    await open(page, '#/pacientes/p1?perfil=responsavel');
    check('iphone: ficha da crianca para o responsavel', await waitText(page, 'Saúde e desenvolvimento'), hash(page));
    await tap(page, 'Saúde e desenvolvimento');
    check('iphone: abre saude e desenvolvimento', hash(page) === '#/rotina/p1/saude', hash(page));
    check('iphone: proximas consultas com orientacoes', await waitText(page, 'Antes da consulta'), '');
    await page.screenshot({ path: path.join(OUT, 'ios02_saude.png') });
    await tap(page, 'Voltar');
    check('iphone: botao voltar do app leva a ficha', hash(page) === '#/pacientes/p1', hash(page));
    await tap(page, 'Documentos da consulta');
    check('iphone: documentos liberados', (await waitText(page, 'Receituário')) && !(await labels(page)).includes('Atestado médico'), hash(page));
    await page.screenshot({ path: path.join(OUT, 'ios03_documentos.png') });
    await tap(page, 'Receituário');
    check('iphone: receita aberta', await waitText(page, 'Emitido em'), hash(page));
    await page.screenshot({ path: path.join(OUT, 'ios04_receita.png') });
    await page.goBack();
    await page.waitForTimeout(2000);
    check('iphone: voltar do navegador volta aos documentos', hash(page).startsWith('#/rotina/p1/documentos'), hash(page));
    await open(page, '#/rotina/p1/documentos/d1?perfil=responsavel');
    check('iphone: documento nao liberado nao abre', await waitText(page, 'Documento não encontrado'), '');
  });

  await step('iphone: pre-consulta e diario', async () => {
    await open(page, '#/pre-consulta/a6?perfil=responsavel');
    check('iphone: pre-consulta com orientacoes da clinica', await waitText(page, 'Pré-consulta'), hash(page));
    await page.screenshot({ path: path.join(OUT, 'ios05_preconsulta.png') });
    await open(page, '#/rotina/p1?perfil=responsavel');
    check('iphone: diario e calendario da crianca', await waitText(page, 'Calendário'), hash(page));
    await page.screenshot({ path: path.join(OUT, 'ios06_rotina.png') });
  });

  await step('iphone: profissional', async () => {
    await open(page, '#/inicio?perfil=profissional');
    check('iphone: inicio do profissional', await waitText(page, 'Agenda'), hash(page));
    await page.screenshot({ path: path.join(OUT, 'ios07_profissional.png') });
    await open(page, '#/pacientes/p1/pre-consulta?perfil=profissional');
    check('iphone: resumo organizado da pre-consulta', await waitText(page, 'Resumo organizado'), hash(page));
    await page.screenshot({ path: path.join(OUT, 'ios08_resumo.png') });
  });

  await browser.close();
  console.log('RESUMO: ' + results.filter(Boolean).length + '/' + results.length + ' verificacoes aprovadas');
  console.log('Erros de pagina: ' + pageErrors.join(' | '));
})();
