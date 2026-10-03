// E2E da area do profissional na demonstracao publicada (dados ficticios).
// Requer Node, playwright-core e Google Chrome instalados:
//   npm i playwright-core && node tools/demo/e2e_clinico.js
// Variaveis opcionais: BASE (URL), OUT (pasta das capturas), ONLY e DOC (filtros).
// Cada bloco usa um contexto novo (equivalente a janela anonima).
const { chromium } = require('playwright-core');
const fs = require('fs');
const path = require('path');

const BASE = process.env.BASE || 'https://draraiany-source.github.io/pediatria360-demo/';
const OUT = process.env.OUT || path.join(require('os').tmpdir(), 'p360-e2e-clinico');
fs.mkdirSync(OUT, { recursive: true });

const ANDROID_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Mobile Safari/537.36';
// Com UA de Android o Flutter exige um toque real para ligar a acessibilidade,
// o que o navegador automatizado nao reproduz; o UA muda so antes de imprimir.
const MOBILE = { viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };
const DESKTOP = { viewport: { width: 1366, height: 860 }, deviceScaleFactor: 1 };

const report = { checks: [], consoleErrors: [], csp: [], pageErrors: [] };
function check(name, ok, detail) {
  report.checks.push({ name, ok: !!ok, detail: detail || '' });
  console.log((ok ? 'OK   ' : 'FALHA') + ' ' + name + (detail ? ' -> ' + detail : ''));
}

async function newPage(browser, opts) {
  const ctx = await browser.newContext({ ...opts, locale: 'pt-BR', acceptDownloads: true });
  // FAKE_NOW fixa o relogio da pagina: horarios livres e prazos dependem da hora da execucao.
  if (process.env.FAKE_NOW) await ctx.clock.setFixedTime(new Date(process.env.FAKE_NOW));
  const page = await ctx.newPage();
  // Registra os Blobs criados (para ler o PDF sem fetch, que a CSP bloqueia) e
  // troca apenas a chamada final de print() do quadro: o navegador automatizado
  // nao abre o dialogo de impressao do sistema e trava o renderizador.
  await ctx.addInitScript(() => {
    window.__blobs = {};
    const create = URL.createObjectURL.bind(URL);
    URL.createObjectURL = (b) => { const u = create(b); window.__blobs[u] = b; return u; };
    const append = Element.prototype.appendChild;
    Element.prototype.appendChild = function (n) {
      if (n && n.id === 'p360-print-frame') {
        const onload = n.onload;
        n.onload = function () {
          try { n.contentWindow.print = () => { window.__printCalled = (window.__printCalled || 0) + 1; }; } catch (e) { window.__printErr = String(e); }
          if (onload) onload.call(n);
        };
      }
      return append.call(this, n);
    };
  });
  page.on('response', (r) => { if (r.status() >= 400) report.consoleErrors.push('HTTP ' + r.status() + ' ' + r.url()); });
  page.on('console', (m) => {
    if (m.type() === 'error') report.consoleErrors.push(m.text().slice(0, 200));
    if (/Content Security Policy|Refused to/i.test(m.text())) report.csp.push(m.text().slice(0, 200));
  });
  page.on('pageerror', (e) => report.pageErrors.push(String(e).slice(0, 200)));
  return { ctx, page };
}

async function ready(page) {
  await page.waitForFunction(() => document.getElementById('loading')?.classList.contains('hidden'), null, { timeout: 60000 });
  await page.waitForTimeout(1500);
  await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await page.waitForTimeout(1500);
}

async function open(page, route) {
  await page.goto(BASE + route);
  await ready(page);
}

async function nav(page, route) {
  await page.evaluate((r) => { location.hash = r; }, route);
  await page.waitForTimeout(2200);
}

async function labels(page) {
  return page.evaluate(() => [...document.querySelectorAll('flt-semantics-host *')]
    .map((e) => [e.getAttribute('aria-label') || '', e.children.length ? '' : (e.textContent || ''), e.value || ''].join(' ').trim())
    .filter(Boolean).join(' | ').replace(/\s+/g, ' '));
}

async function has(page, text) { return (await labels(page)).includes(text); }

async function scrollTo(page, text, tries = 14) {
  const vw = page.viewportSize().width;
  const vh = page.viewportSize().height;
  for (let i = 0; i < tries; i++) {
    if (await has(page, text)) return true;
    await page.mouse.move(vw / 2 + (vw > 900 ? 110 : 0), vh / 2);
    await page.mouse.wheel(0, 500);
    await page.waitForTimeout(500);
  }
  return has(page, text);
}

async function waitText(page, text, timeout = 8000) {
  const end = Date.now() + timeout;
  while (Date.now() < end) {
    if (await has(page, text)) return true;
    await page.waitForTimeout(400);
  }
  return false;
}

// Localiza um no de semantica pelo inicio do rotulo/texto.
async function find(page, label, opts = {}) {
  return page.evaluate(({ label, opts }) => {
    const roles = ['button', 'tab', 'link', 'menuitem', 'checkbox', 'option', 'radio'];
    const sel = opts.input ? 'input, textarea' : 'flt-semantics';
    const els = [...document.querySelectorAll(sel)].filter((e) => opts.input || roles.includes(e.getAttribute('role')) || e.hasAttribute('flt-tappable'));
    const text = (e) => (e.getAttribute('aria-label') || e.textContent || '').replace(/\s+/g, ' ').trim();
    let matches = els.filter((e) => (opts.exact ? text(e) === label : opts.contains ? text(e).includes(label) : text(e).startsWith(label)));
    // after: so vale o botao que vem depois do no mais interno com esse texto.
    if (opts.after) {
      const all = [...document.querySelectorAll('flt-semantics')].filter((e) => text(e).includes(opts.after));
      const anchor = all.find((a) => !all.some((b) => b !== a && a.contains(b)));
      matches = anchor ? matches.filter((e) => anchor.compareDocumentPosition(e) & Node.DOCUMENT_POSITION_FOLLOWING) : [];
    }
    const el = opts.last ? matches[matches.length - 1] : matches[0];
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2, disabled: el.getAttribute('aria-disabled') === 'true' || el.hasAttribute('disabled'), checked: el.getAttribute('aria-checked') };
  }, { label, opts });
}

async function reveal(page, label, opts = {}) {
  const vh = page.viewportSize().height;
  const vw = page.viewportSize().width;
  for (let i = 0; i < 18; i++) {
    const box = await find(page, label, opts);
    // No celular a faixa de baixo tem botao flutuante e barra de navegacao.
    const inY = box && box.y > 70 && box.y < vh - (vw < 600 ? 170 : 90);
    if (inY && box.x > 8 && box.x < vw - 8) return box;
    if (inY) {
      // Fileira de filtros com rolagem horizontal.
      await page.mouse.move(vw / 2, box.y);
      await page.mouse.wheel(box.x - vw / 2, 0);
      await page.waitForTimeout(500);
      continue;
    }
    const dy = box ? box.y - vh / 2 : i < 10 ? 600 : -1500;
    await page.mouse.move(vw / 2 + (vw > 900 ? 110 : 0), vh / 2);
    await page.mouse.wheel(0, dy);
    await page.waitForTimeout(500);
  }
  const box = await find(page, label, opts);
  if (!box) {
    const l = await labels(page);
    throw new Error('nao encontrado: ' + label + ' | tela: ' + l.slice(0, 300));
  }
  return box;
}

async function tap(page, label, opts = {}) {
  const box = await reveal(page, label, opts);
  if (opts.touch) await page.touchscreen.tap(box.x, box.y);
  else await page.mouse.click(box.x, box.y);
  await page.waitForTimeout(opts.wait || 1200);
}

async function fill(page, label, value, opts = {}) {
  const box = await reveal(page, label, { ...opts, input: true });
  if (opts.touch) await page.touchscreen.tap(box.x, box.y); else await page.mouse.click(box.x, box.y);
  for (let attempt = 0; attempt < 3; attempt++) {
    await page.waitForTimeout(700);
    await page.keyboard.press('Control+A');
    await page.keyboard.press('Backspace');
    await page.keyboard.type(value, { delay: 25 });
    await page.waitForTimeout(500);
    const v = await page.evaluate(() => document.activeElement && document.activeElement.value);
    if (v === value) return;
  }
  throw new Error('valor nao digitado em ' + label);
}

async function choose(page, field, option, touch) {
  await tap(page, field, { touch });
  await page.waitForTimeout(500);
  await tap(page, option, { last: true, touch });
}

async function isDisabled(page, label) {
  const b = await reveal(page, label).catch(() => null);
  return b ? b.disabled : null;
}

const hash = (page) => decodeURIComponent(new URL(page.url()).hash);
const shot = (page, name) => page.screenshot({ path: path.join(OUT, name + '.png') });

async function step(name, fn) {
  if (process.env.ONLY && !new RegExp(process.env.ONLY).test(name)) return;
  try { await fn(); } catch (e) { check(name, false, e.message.split('\n')[0]); }
}

async function pdfFromDownload(download) {
  const p = await download.path();
  const b = fs.readFileSync(p);
  return { magic: b.subarray(0, 5).toString('latin1'), size: b.length, name: download.suggestedFilename() };
}

async function blobMagic(page, url) {
  return page.evaluate(async (u) => {
    const blob = window.__blobs[u];
    if (!blob) return null;
    const b = new Uint8Array(await blob.slice(0, 5).arrayBuffer());
    return { magic: String.fromCharCode(...b), size: blob.size, type: blob.type };
  }, url);
}

function pdfImageInfo(buf) {
  const t = buf.toString('latin1');
  return { magic: t.slice(0, 5), image: /\/Subtype\s*\/Image/.test(t), widths: [...t.matchAll(/\/Width\s*(\d+)/g)].map((m) => +m[1]) };
}

async function blobImageInfo(page, url) {
  return page.evaluate(async (u) => {
    const blob = window.__blobs[u];
    if (!blob) return null;
    const b = new Uint8Array(await blob.arrayBuffer());
    let t = '';
    for (let i = 0; i < b.length; i += 8192) t += String.fromCharCode.apply(null, b.subarray(i, i + 8192));
    return { magic: t.slice(0, 5), image: /\/Subtype\s*\/Image/.test(t), widths: [...t.matchAll(/\/Width\s*(\d+)/g)].map((m) => +m[1]) };
  }, url);
}

// Logomarca ficticia desenhada num canvas da propria pagina.
async function makeLogo(page, { w = 600, h = 200, text = 'Clinica Exemplo', color = '#14676B', type = 'image/png' } = {}) {
  const b64 = await page.evaluate(({ w, h, text, color, type }) => {
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    const g = c.getContext('2d');
    g.fillStyle = '#ffffff';
    g.fillRect(0, 0, w, h);
    g.fillStyle = color;
    g.beginPath();
    g.arc(h / 2, h / 2, h * 0.38, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = '#ffffff';
    g.font = 'bold ' + Math.round(h * 0.3) + 'px sans-serif';
    g.textAlign = 'center';
    g.textBaseline = 'middle';
    g.fillText('CE', h / 2, h / 2);
    g.textAlign = 'left';
    g.fillStyle = color;
    g.font = 'bold ' + Math.round(h * 0.2) + 'px sans-serif';
    g.fillText(text, h * 0.95, h * 0.42);
    g.fillStyle = '#4A5B7A';
    g.font = Math.round(h * 0.11) + 'px sans-serif';
    g.fillText('logomarca ficticia de teste', h * 0.95, h * 0.7);
    return c.toDataURL(type, 0.92).split(',')[1];
  }, { w, h, text, color, type });
  return Buffer.from(b64, 'base64');
}

const DOCS = [
  { slug: 'atestado', label: 'Atestado médico', fields: [] },
  { slug: 'declaracao', label: 'Declaração de comparecimento', fields: [['Das *', '08:00'], ['Às *', '09:00']] },
  { slug: 'encaminhamento', label: 'Encaminhamento', fields: [['Especialidade de destino *', 'Especialidade Exemplo'], ['Motivo do encaminhamento *', 'Motivo fictício'], ['Resumo clínico *', 'Resumo clínico fictício'], ['Exames relevantes', 'Exame exemplo'], ['Tratamentos realizados', 'Tratamento exemplo']] },
  { slug: 'orientacoes', label: 'Orientações ao responsável', fields: [['Título *', 'Cuidados'], ['Orientações *', 'Texto fictício de orientação.']] },
  { slug: 'exames', label: 'Solicitação de exames', fields: [['Exames (um por linha) *', 'Exame A'], ['Indicação clínica *', 'Indicação fictícia']] },
  { slug: 'receituario', label: 'Receituário', fields: [] },
];

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });

  // ---------- Computador ----------
  await step('computador: inicio profissional', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/inicio?perfil=profissional');
    const hi = [await has(page, 'Consultas de hoje'), await has(page, 'Calculadora Guia'), await has(page, 'Suplementação Guia')];
    check('computador: inicio com consultas e menu lateral acessivel', hi.every(Boolean), hi.join('/'));
    await shot(page, 'd01_inicio_profissional');
    await ctx.close();
  });

  await step('computador: calculadora mg/kg/dose', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/calculadora?paciente=p1&perfil=profissional');
    check('calc: peso e data da pesagem exibidos', await has(page, '10,2 kg em'), '');
    await choose(page, 'Medicamento *', 'Medicamento Exemplo A');
    await choose(page, 'Apresentação *', 'Suspensão 100 mg/5 mL');
    const l = await labels(page);
    check('calc mg/kg/dose: 15 mg/kg x 10,2 kg = 153 mg', l.includes('15 mg/kg/dose × 10,2 kg = 153 mg por dose'), '');
    check('calc mg->mL: 153 mg ÷ 20 mg/mL = 7,65 mL', l.includes('153 mg ÷ 20 mg/mL') && l.includes('7,65 mL por dose'), '');
    check('calc: dose por administracao 7,7 mL e diaria 612 mg/dia', l.includes('7,7 mL por dose') && l.includes('612 mg/dia'), '');
    check('calc: inserir bloqueado antes das conferencias', (await isDisabled(page, 'Inserir em novo receituário')) === true, '');
    await shot(page, 'd02_calc_mgkg_dose');
    await fill(page, 'Duração *', '5 dias');
    await tap(page, 'Conferi o resultado');
    check('calc: ainda bloqueado sem conferir a apresentacao', (await isDisabled(page, 'Inserir em novo receituário')) === true, '');
    await tap(page, 'Conferi a apresentação');
    check('calc: liberado apos as duas conferencias', (await isDisabled(page, 'Inserir em novo receituário')) === false, '');
    await tap(page, 'Inserir em novo receituário', { wait: 2500 });
    const h = hash(page);
    check('calc: insere em receituario RASCUNHO para revisao', h.includes('/documentos/') && h.endsWith('/editar') && (await has(page, '7,7 mL (153 mg) por dose')), h);
    await shot(page, 'd03_receituario_com_item_calculado');
    await ctx.close();
  });

  await step('computador: calculadora mg/kg/dia', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/calculadora?paciente=p5&perfil=profissional');
    await choose(page, 'Medicamento *', 'Medicamento Exemplo B');
    await choose(page, 'Apresentação *', 'Suspensão 250 mg/5 mL');
    const l = await labels(page);
    check('calc mg/kg/dia: 40 x 12,8 = 512 mg/dia ÷ 2 = 256 mg -> 5,1 mL', l.includes('40 mg/kg/dia × 12,8 kg = 512 mg/dia') && l.includes('256 mg por dose') && l.includes('5,1 mL por dose'), '');
    await shot(page, 'd04_calc_mgkg_dia');
    await ctx.close();
  });

  await step('computador: dose maxima', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/calculadora?paciente=p4&perfil=profissional');
    await choose(page, 'Medicamento *', 'Medicamento Exemplo A');
    await choose(page, 'Apresentação *', 'Suspensão 100 mg/5 mL');
    await fill(page, 'Dose prescrita *', '16');
    check('dose maxima: alerta critico e insercao impedida', (await waitText(page, 'acima do máximo de 500 mg')) && (await has(page, 'Impede a inserção')), '');
    await page.mouse.move(800, 430); await page.mouse.wheel(0, 650); await page.waitForTimeout(700);
    await shot(page, 'd05_dose_acima_maximo');
    await tap(page, 'Limitar à dose máxima');
    check('dose maxima: limitada a 500 mg = 25 mL com alerta', (await waitText(page, '25 mL por dose')) && (await has(page, 'Limitado à dose máxima')), '');
    await ctx.close();
  });

  await step('computador: bloqueios', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    const cases = [
      ['p3', 'Medicamento Exemplo A', 'Suspensão 100 mg/5 mL', 'Peso não registrado', 'sem peso bloqueia'],
      ['p1', 'Medicamento Exemplo C', null, 'ainda não foi validada', 'referencia nao validada bloqueia'],
      ['p4', 'Medicamento Exemplo B', 'Suspensão 250 mg/5 mL', 'Alergia registrada', 'alergia bloqueia'],
      ['p1', 'Medicamento Exemplo B', 'Suspensão 250 mg/5 mL', 'restrição de idade', 'restricao de idade bloqueia'],
      ['p2', 'Medicamento Exemplo A', 'Suspensão 100 mg/5 mL', 'Considere pesar novamente', 'peso desatualizado alerta'],
      ['p1', 'Medicamento Exemplo A', 'Comprimido 500 mg', 'não é adequada para', 'apresentacao incompativel bloqueia'],
    ];
    let first = true;
    for (const [p, med, pres, expected, name] of cases) {
      if (first) { await open(page, '#/calculadora?paciente=' + p + '&perfil=profissional'); first = false; }
      else { await nav(page, '#/inicio'); await nav(page, '#/calculadora?paciente=' + p); }
      await choose(page, 'Medicamento *', med);
      if (pres) await choose(page, 'Apresentação *', pres);
      const ok = await waitText(page, expected, 5000);
      check('calc: ' + name, ok, expected);
      if (p === 'p3') await shot(page, 'd06_calc_bloqueado_sem_peso');
      if (name.startsWith('alergia')) await shot(page, 'd07_calc_alergia');
    }
    await ctx.close();
  });

  await step('computador: documentos', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p2/documentos?perfil=profissional');
    for (const d of DOCS.filter((x) => !process.env.DOC || x.slug === process.env.DOC)) {
      await step('doc ' + d.slug, async () => {
        await nav(page, '#/pacientes/p2/documentos/novo?tipo=' + d.slug);
        const ed = [await waitText(page, 'Novo: ' + d.label), await has(page, 'Theo Exemplo Lima')];
        check(d.label + ': editor preenchido com o paciente', ed.every(Boolean), 'titulo/paciente=' + ed.join('/'));
        for (const [f, v] of d.fields) await fill(page, f, v);
        if (d.slug === 'receituario') {
          await tap(page, 'Adicionar item manualmente');
          const vals = [['Medicamento *', 'Medicamento Exemplo A'], ['Apresentação e concentração *', 'Suspensão 100 mg/5 mL'], ['Dose por administração *', '5 mL'], ['Intervalo *', 'de 8/8h'], ['Duração *', '3 dias']];
          for (const [f, v] of vals) await fill(page, f, v, { last: true });
          await tap(page, 'Salvar item');
          check(d.label + ': item manual marcado como Manual', await waitText(page, 'Manual'), '');
        }
        if (d.slug === 'encaminhamento') await shot(page, 'd08_editor_encaminhamento');
        await tap(page, 'Salvar e revisar', { wait: 1500 });
        await waitText(page, 'Marcar como revisado', 8000);
        const rv = [await has(page, 'Emitir documento'), await isDisabled(page, 'Marcar como revisado')];
        check(d.label + ': emitir so aparece depois de revisar', !rv[0] && rv[1] === true, 'emitirVisivel/revisarDesabilitado=' + rv.join('/'));
        if (!(!rv[0] && rv[1] === true)) { await shot(page, 'dbg_' + d.slug); console.log((await labels(page)).slice(0, 1500)); }
        await tap(page, 'Revisei o conteúdo');
        await tap(page, 'Marcar como revisado');
        await tap(page, 'Emitir documento', { wait: 1800 });
        const l = await labels(page);
        check(d.label + ': emitido e exibido como NAO assinado', l.includes('Emitido') && l.includes('Não assinado') && !l.includes('Assinado digitalmente'), '');
        check(d.label + ': autor/profissional registrado (Dra. Exemplo)', l.includes('Dra. Exemplo Demonstração'), '');
        if (d.slug === 'atestado') await shot(page, 'd09_documento_emitido_nao_assinado');
        await page.waitForTimeout(4500);
        const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 15000 }), tap(page, 'Gerar PDF', { wait: 800 })]);
        const pdf = await pdfFromDownload(dl);
        check(d.label + ': PDF baixado', pdf.magic === '%PDF-' && pdf.size > 1500 && pdf.name.startsWith(d.slug + '-theo-v1'), pdf.name + ' ' + pdf.size + ' bytes');
        fs.copyFileSync(await dl.path(), path.join(OUT, pdf.name));
        await page.waitForTimeout(3500);
        await tap(page, 'Imprimir', { wait: 1500 });
        const src = await page.evaluate(() => document.getElementById('p360-print-frame')?.src || null);
        const pm = src ? await blobMagic(page, src) : null;
        await page.waitForTimeout(1200);
        const printed = await page.evaluate(() => window.__printCalled || 0);
        check(d.label + ': impressao carrega o PDF e chama print()', !!src && src.startsWith('blob:') && pm && pm.magic === '%PDF-' && printed > 0, src ? 'blob ' + (pm && pm.size) + ' bytes, print() chamado ' + printed + 'x' : 'sem iframe');
        await tap(page, 'Voltar aos documentos', { wait: 2000 });
        check(d.label + ': aparece no historico com autor e versao', (await has(page, d.label)) && (await has(page, 'v1 · Dra. Exemplo')), '');
      });
    }
    await shot(page, 'd10_historico_documentos');
    await ctx.close();
  });

  await step('computador: versoes', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/documentos/d1?perfil=profissional');
    check('versoes: v1 e v2 emitidas visiveis', (await has(page, 'v1 · Emitido')) && (await has(page, 'v2 · Emitido')), '');
    await tap(page, 'Criar nova versão', { wait: 2000 });
    check('versoes: editar emitido cria a versao 3', await waitText(page, 'Salvar cria a versão 3'), '');
    await fill(page, 'Dias de afastamento *', '3');
    await tap(page, 'Salvar rascunho', { wait: 1500 });
    check('versoes: correcao de emitido pede motivo', await waitText(page, 'Criar versão 3'), '');
    await fill(page, 'Motivo da correção *', 'Período ajustado a pedido da escola');
    await tap(page, 'Salvar nova versão', { wait: 1500 });
    await nav(page, '#/pacientes/p1/documentos/d1');
    check('versoes: v3 rascunho e anteriores preservadas', (await waitText(page, 'v3 · Rascunho')) && (await has(page, 'v2 · Emitido')), '');
    check('versoes: historico registra autor e motivo', await has(page, 'Correção: Período ajustado a pedido da escola'), '');
    await shot(page, 'd11_versoes');
    await ctx.close();
  });

  await step('computador: consulta', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p2?perfil=profissional');
    await tap(page, 'Iniciar consulta', { wait: 2500 });
    check('consulta: abre na etapa Consulta', hash(page).includes('/consulta/'), hash(page));
    await fill(page, 'Motivo da consulta *', 'Motivo fictício');
    await shot(page, 'd12_consulta_etapa1');
    await tap(page, 'Salvar rascunho', { wait: 1500 });
    await tap(page, 'Próximo', { wait: 1500 });
    await fill(page, 'Peso de hoje', '17,1');
    await fill(page, 'Avaliação *', 'Avaliação fictícia');
    await tap(page, 'Próximo', { wait: 1500 });
    await fill(page, 'Conduta *', 'Conduta fictícia');
    check('consulta: conduta oferece receituario com calculadora e suplementacao', (await has(page, 'Receituário com calculadora')) && (await has(page, 'Suplementação do paciente')), '');
    await shot(page, 'd13_consulta_conduta');
    await tap(page, 'Retorno em 30 dias', { wait: 900 });
    await tap(page, 'Próximo', { wait: 1500 });
    await tap(page, 'Finalizar consulta', { wait: 1500 });
    await tap(page, 'Finalizar', { last: true, wait: 2500 });
    check('consulta: finalizar abre o resumo com retorno', hash(page).endsWith('/resumo') && (await waitText(page, 'Motivo fictício')) && (await has(page, 'Retorno recomendado')), hash(page));
    await nav(page, '#/pacientes/p2/prontuario');
    check('consulta: finalizada aparece no prontuario e peso atualizado', (await waitText(page, 'Motivo fictício')) && (await has(page, '17,1 kg')), '');
    await shot(page, 'd14_prontuario_apos_consulta');
    await ctx.close();
  });

  await step('computador: suplementacao', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/suplementacao?perfil=profissional');
    const l = await labels(page);
    const temas = ['Exames laboratoriais', 'Ferro', 'B12', 'Ácido fólico', 'Zinco', 'B6', 'Vitamina A', 'Vitamina D', 'Vitamina E', 'Vitamina K', 'Vitamina C', 'Magnésio', 'Ômega', 'Cálcio', 'Complexo B', 'Selênio', 'Cobre'];
    const faltam = [];
    for (const t of temas) if (!l.includes(t)) faltam.push(t);
    check('suplementacao: 17 temas, 0 validados, aviso de rascunho', l.includes('17 temas') && l.includes('0 validados') && /rascunho/i.test(l), faltam.length ? 'nao visiveis sem rolar: ' + faltam.join(', ') : '');
    await shot(page, 'd15_suplementacao_lista');
    await tap(page, 'Ferro');
    check('suplementacao: ficha em RASCUNHO sem conteudo clinico', (await waitText(page, 'RASCUNHO')) && (await has(page, 'Não preenchido')), '');
    await shot(page, 'd16_suplementacao_ficha_rascunho');
    await ctx.close();
  });

  await step('computador: permissoes', async () => {
    const cases = [
      ['recepcao', '#/calculadora'], ['recepcao', '#/pacientes/p1/documentos'], ['recepcao', '#/suplementacao'],
      ['responsavel', '#/calculadora'], ['responsavel', '#/pacientes/p1/documentos/d1'],
      ['financeiro', '#/pacientes/p1/consulta/c1'], ['administrador', '#/suplementacao'],
    ];
    for (const [perfil, route] of cases) {
      const { ctx, page } = await newPage(browser, DESKTOP);
      await open(page, route + '?perfil=' + perfil);
      const l = await labels(page);
      const blocked = l.includes('Acesso restrito') || !(l.includes('Calculadora de doses') || l.includes('Atestado') || l.includes('Suplementação na pediatria'));
      check('permissao: ' + perfil + ' bloqueado em ' + route, blocked && !l.includes('Emitir documento') && !l.includes('Inserir em novo receituário'), l.includes('Acesso restrito') ? 'Acesso restrito' : 'sem modulo');
      if (perfil === 'recepcao' && route === '#/calculadora') await shot(page, 'd17_recepcao_sem_calculadora');
      await ctx.close();
    }
  });

  // ---------- Crescimento, exames e suplementacao do paciente ----------
  const pad = (n) => String(n).padStart(2, '0');
  const now = new Date();
  const TODAY = pad(now.getDate()) + '/' + pad(now.getMonth() + 1) + '/' + now.getFullYear();
  const LAUDO = path.join(OUT, 'laudo-ficticio-e2e.pdf');
  fs.writeFileSync(LAUDO, '%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 200 200]>>endobj\ntrailer<</Root 1 0 R>>\n%%EOF\n');

  await step('computador: curva de crescimento', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/crescimento?perfil=profissional');
    await waitText(page, 'Curva de crescimento');
    const l = await labels(page);
    check('curva: idade cronologica, corrigida e IG ao nascer', l.includes('Idade cronológica hoje') && l.includes('Idade corrigida hoje') && l.includes('34 semanas e 2 dias'), '');
    check('curva: referencia OMS identificada', l.includes('OMS 2006'), '');
    check('curva: escore Z e percentil por ponto', l.includes('Escore Z') && l.includes('percentil'), '');
    check('curva: grafico com descricao acessivel', l.includes('Gráfico Peso para idade'), '');
    check('curva: ponto antes do termo corrigido sem escore', l.includes('referência neonatal'), '');
    await shot(page, 'c01_curva_peso_profissional');
    await tap(page, 'Comprimento/altura');
    check('curva: comprimento com medida corrigida marcada', (await waitText(page, 'Gráfico Comprimento/altura')) && (await has(page, 'Corrigida')), '');
    await shot(page, 'c02_curva_comprimento_corrigida');
    await tap(page, 'Perímetro cefálico');
    check('curva: perimetro cefalico', await waitText(page, 'Gráfico Perímetro cefálico'), '');
    await shot(page, 'c03_curva_perimetro_cefalico');
    await page.waitForTimeout(3000);
    const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 20000 }), tap(page, 'Exportar PDF', { wait: 800 })]);
    const pdf = await pdfFromDownload(dl);
    check('curva: PDF exportado', pdf.magic === '%PDF-' && pdf.size > 3000 && pdf.name.startsWith('curvas-luna'), pdf.name + ' ' + pdf.size + ' bytes');
    fs.copyFileSync(await dl.path(), path.join(OUT, pdf.name));
    await page.waitForTimeout(3500);
    await tap(page, 'Imprimir', { wait: 2500 });
    const src = await page.evaluate(() => document.getElementById('p360-print-frame')?.src || null);
    const pm = src ? await blobMagic(page, src) : null;
    await page.waitForTimeout(1200);
    const printed = await page.evaluate(() => window.__printCalled || 0);
    check('curva: impressao carrega o PDF e chama print()', !!pm && pm.magic === '%PDF-' && printed > 0, src ? 'print() ' + printed + 'x' : 'sem iframe');
    await reveal(page, 'Retornar ao paciente');
    check('curva: historico de alteracoes com motivo', (await has(page, 'Histórico de alterações')) && (await has(page, 'Dígitos invertidos')), '');
    await shot(page, 'c04_historico_alteracoes');
    await ctx.close();
  });

  await step('computador: corrigir medida', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/crescimento?perfil=profissional');
    await tap(page, 'Corrigir medida de', { wait: 2000 });
    check('corrigir: abre a tela de correcao', await waitText(page, 'Salvar correção'), hash(page));
    await fill(page, 'Peso', '10,1');
    await tap(page, 'Salvar correção', { wait: 1500 });
    check('corrigir: exige motivo', await waitText(page, 'Informe o motivo da correção.'), '');
    await fill(page, 'Motivo da correção *', 'Balança sem tara (teste e2e)');
    await shot(page, 'c05_corrigir_medida');
    await tap(page, 'Salvar correção', { wait: 2500 });
    check('corrigir: volta a curva e guarda o motivo no historico', (await waitText(page, 'Curva de crescimento')) && (await waitText(page, 'Balança sem tara (teste e2e)')), hash(page));
    await ctx.close();
  });

  await step('computador: exames', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/exames?perfil=profissional');
    await waitText(page, 'Exames laboratoriais');
    check('exames: pendente separado da linha do tempo', await has(page, 'Pendentes de conferência (1)'), '');
    check('exames: regra de intervalo do laudo exibida', await has(page, 'não há intervalo único'), '');
    await shot(page, 'c06_exames_linha_do_tempo');
    const [fc] = await Promise.all([page.waitForEvent('filechooser', { timeout: 15000 }), tap(page, 'Importar laudo', { wait: 500 })]);
    await fc.setFiles(LAUDO);
    check('exames: laudo importado abre a conferencia', await waitText(page, 'Conferir laudo importado', 10000), hash(page));
    const editar = hash(page);
    check('exames: nada lido automaticamente do arquivo', await has(page, 'Nada foi lido automaticamente'), '');
    await fill(page, 'Exame *', 'Ferritina');
    await fill(page, 'Resultado *', '22');
    await fill(page, 'Unidade *', 'ng/mL');
    await fill(page, 'Data da coleta *', TODAY);
    await fill(page, 'Laboratório *', 'Laboratório Exemplo C');
    await fill(page, 'Intervalo como no laudo', '15 a 160 ng/mL (laudo C)');
    await fill(page, 'Limite inferior', '15');
    await fill(page, 'Limite superior', '160');
    await tap(page, 'Salvar rascunho', { wait: 1500 });
    await shot(page, 'c07_conferencia_laudo');
    await nav(page, '#/pacientes/p1/prontuario');
    await waitText(page, 'Exames conferidos');
    check('exames: pendente NAO entra no prontuario', !(await has(page, '22 ng/mL')) && (await has(page, 'aguardando conferência')), '');
    await nav(page, editar);
    await waitText(page, 'Conferir laudo importado');
    await tap(page, 'Confirmar e liberar', { wait: 1500 });
    check('exames: confirmar exige marcar a conferencia', await waitText(page, 'Marque que conferiu'), '');
    await tap(page, 'Conferi os valores com o arquivo original');
    await tap(page, 'Confirmar e liberar', { wait: 2500 });
    const l = await labels(page);
    check('exames: conferido com intervalo do proprio laudo', l.includes('15 a 160 ng/mL (laudo C)') && l.includes('Dentro do intervalo do laudo'), '');
    await shot(page, 'c08_exame_conferido');
    const [popup] = await Promise.all([ctx.waitForEvent('page', { timeout: 15000 }), tap(page, 'Abrir arquivo original', { wait: 800 })]);
    const pu = popup.url();
    const om = pu.startsWith('blob:') ? await blobMagic(page, pu) : null;
    check('exames: arquivo original abre em nova aba', !!om && om.magic === '%PDF-', pu.slice(0, 30));
    await popup.close();
    await nav(page, '#/pacientes/p1/prontuario');
    check('exames: apos conferir entra no prontuario', await waitText(page, '22 ng/mL'), '');
    await nav(page, '#/pacientes/p1/exames');
    await tap(page, 'Ferritina (3)');
    const s = await labels(page);
    check('exames: comparacao no tempo com laudos diferentes', s.includes('laudo A') && s.includes('laudo B') && s.includes('laudo C'), '');
    await shot(page, 'c09_comparacao_ferritina');
    await ctx.close();
  });

  await step('computador: suplementacao do paciente', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/suplementacao?perfil=profissional');
    await waitText(page, 'Suplementação do paciente');
    check('supl paciente: temas com ficha em rascunho identificada', await has(page, 'Ficha em rascunho'), '');
    await shot(page, 'c10_suplementacao_paciente');
    await nav(page, '#/pacientes/p1/suplementacao/ferro');
    await waitText(page, 'Ferro - decisão');
    const l = await labels(page);
    check('supl paciente: fonte e data da ultima revisao exibidas', l.includes('Fonte:') && l.includes('Última revisão:'), '');
    check('supl paciente: exames conferidos relacionados', l.includes('Ferritina'), '');
    await tap(page, 'Suplementação indicada');
    await fill(page, 'Justificativa e registro da decisão *', 'Decisão fictícia registrada no teste.');
    await tap(page, 'Salvar nova versão', { wait: 1800 });
    check('supl paciente: nova versao no historico', await waitText(page, 'Acompanhar e reavaliar'), '');
    await shot(page, 'c11_decisao_suplementacao');
    await tap(page, 'Levar à calculadora e ao receituário', { wait: 2000 });
    check('supl paciente: calculadora mostra a origem da decisao', await waitText(page, 'Origem: decisão de suplementação - Ferro'), '');
    await choose(page, 'Medicamento *', 'Suplemento Exemplo D');
    await choose(page, 'Apresentação *', 'Gotas 10 mg/mL');
    await fill(page, 'Duração *', '30 dias');
    await tap(page, 'Conferi o resultado');
    await tap(page, 'Conferi a apresentação');
    await shot(page, 'c12_calculadora_origem_decisao');
    await tap(page, 'Inserir na receita', { wait: 2500 });
    const h = hash(page);
    check('supl paciente: item vai para receituario em rascunho', h.includes('/documentos/') && h.endsWith('/editar') && (await has(page, 'Suplemento Exemplo D')), h);
    await shot(page, 'c13_receituario_da_decisao');
    await ctx.close();
  });

  await step('computador: permissoes crescimento e exames', async () => {
    const cases = [
      ['recepcao', '#/pacientes/p1/crescimento'], ['recepcao', '#/pacientes/p1/exames'],
      ['financeiro', '#/pacientes/p1/suplementacao'], ['administrador', '#/pacientes/p1/crescimento'],
      ['responsavel', '#/pacientes/p1/exames'], ['responsavel', '#/pacientes/p1/crescimento/nova'],
    ];
    for (const [perfil, route] of cases) {
      const { ctx, page } = await newPage(browser, DESKTOP);
      await open(page, route + '?perfil=' + perfil);
      check('permissao: ' + perfil + ' bloqueado em ' + route, await waitText(page, 'Acesso restrito'), '');
      if (perfil === 'recepcao' && route.endsWith('crescimento')) await shot(page, 'c14_recepcao_sem_curva');
      await ctx.close();
    }
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/crescimento?perfil=responsavel');
    await waitText(page, 'Últimas medidas');
    const l = await labels(page);
    check('responsavel: visao simples sem escore, sem exportar e sem editar', l.includes('Últimas medidas') && !l.includes('Escore Z') && !l.includes('Exportar PDF') && !l.includes('Corrigir medida'), '');
    await shot(page, 'c15_responsavel_visao_simples');
    await nav(page, '#/pacientes/p2/crescimento');
    check('responsavel: nao ve crianca de outra familia', await waitText(page, 'Paciente não encontrado'), '');
    await ctx.close();
  });

  // ---------- Celular ----------
  await step('celular: calculadora por toque', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/calculadora?paciente=p1&perfil=profissional');
    await choose(page, 'Medicamento *', 'Medicamento Exemplo A', true);
    await choose(page, 'Apresentação *', 'Suspensão 100 mg/5 mL', true);
    check('celular calc: 7,7 mL por dose', await waitText(page, '7,7 mL por dose'), '');
    await shot(page, 'm01_calc');
    await ctx.close();
  });

  await step('celular: documento PDF e impressao', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/pacientes/p1/documentos/d1?perfil=profissional');
    await shot(page, 'm02_documento');
    const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 15000 }), tap(page, 'Gerar PDF', { touch: true, wait: 800 })]);
    const pdf = await pdfFromDownload(dl);
    check('celular: PDF baixado', pdf.magic === '%PDF-', pdf.name + ' ' + pdf.size + ' bytes');
    await page.waitForTimeout(3500);
    await page.evaluate((ua) => Object.defineProperty(navigator, 'userAgent', { get: () => ua }), ANDROID_UA);
    const [popup] = await Promise.all([ctx.waitForEvent('page', { timeout: 15000 }), tap(page, 'Imprimir', { touch: true, wait: 800 })]);
    const u = popup.url();
    const pm = u.startsWith('blob:') ? await blobMagic(page, u) : null;
    check('celular: imprimir abre o PDF em nova aba', !!pm && pm.magic === '%PDF-', u.slice(0, 40));
    await ctx.close();
  });

  await step('celular: consulta e barra de acoes', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/pacientes/p5/consulta/c2?perfil=profissional');
    const l = await labels(page);
    check('celular: fluxo com Voltar, Cancelar, Salvar rascunho e Proximo', ['Voltar', 'Cancelar', 'Salvar rascunho', 'Próximo'].every((x) => l.includes(x)), '');
    await shot(page, 'm03_consulta');
    await open(page, '#/inicio?perfil=profissional');
    await shot(page, 'm04_inicio');
    await ctx.close();
  });

  await step('celular: crescimento, exames e suplementacao', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/pacientes/p1/crescimento?perfil=profissional');
    check('celular: curva do profissional', (await waitText(page, 'Curva de crescimento')) && (await has(page, 'Escore Z')), '');
    await shot(page, 'm05_curva_profissional');
    await nav(page, '#/pacientes/p1/exames');
    check('celular: exames', await waitText(page, 'Pendentes de conferência'), '');
    await shot(page, 'm06_exames');
    await nav(page, '#/pacientes/p1/exames/l6/editar');
    check('celular: conferencia do laudo', await waitText(page, 'Conferir laudo importado'), '');
    await shot(page, 'm07_conferencia_laudo');
    await nav(page, '#/pacientes/p1/suplementacao/ferro');
    check('celular: decisao de suplementacao', await waitText(page, 'Ferro - decisão'), '');
    await shot(page, 'm08_decisao_suplementacao');
    await ctx.close();
    const r = await newPage(browser, MOBILE);
    await open(r.page, '#/pacientes/p1/crescimento?perfil=responsavel');
    check('celular: visao simples do responsavel', (await waitText(r.page, 'Últimas medidas')) && !(await has(r.page, 'Escore Z')), '');
    await shot(r.page, 'm09_responsavel_curva');
    await r.ctx.close();
  });

  // ---------- Rotina da crianca (celular, dados ficticios) ----------
  const MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
  const dmy = (d) => pad(d.getDate()) + '/' + pad(d.getMonth() + 1) + '/' + d.getFullYear();
  const dkey = (d) => d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
  const hm = (d) => pad(d.getHours()) + ':' + pad(d.getMinutes());
  const addDays = (d, n) => new Date(d.getFullYear(), d.getMonth(), d.getDate() + n);

  await step('celular: rotina calendario e diario', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/rotina?perfil=responsavel');
    check('rotina: calendario abre com Calendario/Diario', (await waitText(page, 'Rotina da criança')) && (await has(page, 'Calendário')) && (await has(page, 'Diário')), hash(page));
    await shot(page, 'r01_calendario_mes');
    const d1 = addDays(new Date(), -1);
    await tap(page, d1.getDate() + ' de ' + MESES[d1.getMonth()], { touch: true, wait: 1800 });
    const dayHash = hash(page);
    await reveal(page, 'Abrir no diário');
    check('rotina: toque no dia mostra compromissos e diario do dia', dayHash.includes('dia=' + dkey(d1)) && (await has(page, 'Diário do dia')), dayHash);
    await shot(page, 'r02_dia_com_diario');
    await reveal(page, 'Mamão amassado (exemplo)', { contains: true });
    check('rotina: linha do tempo do dia com autor', (await has(page, 'Mamão amassado (exemplo)')) && (await has(page, 'Informado pela família')), '');
    await shot(page, 'r02b_linha_do_tempo_do_dia');
    await tap(page, 'Abrir no diário', { touch: true, wait: 1800 });
    check('rotina: troca para o diario no mesmo dia', hash(page).includes('vista=diario') && hash(page).includes('dia=' + dkey(d1)) && (await waitText(page, 'Linha do tempo')), hash(page));
    await shot(page, 'r03_diario_do_dia');
    await tap(page, 'Fralda (', { touch: true, wait: 1500 });
    await reveal(page, 'Xixi e cocô', { contains: true });
    check('rotina: filtro por tipo no diario', (await has(page, 'Xixi e cocô')) && !(await has(page, 'Mamão amassado')), '');
    await shot(page, 'r04_filtro_fralda');
    await tap(page, 'Todos (', { touch: true });
    await tap(page, 'Calendário', { touch: true, wait: 1800 });
    check('rotina: volta ao calendario', hash(page).includes('vista=calendario'), hash(page));
    await tap(page, 'Semana', { touch: true, wait: 1800 });
    check('rotina: visao semanal', (await waitText(page, 'Semana de')) && hash(page).includes('modo=semana'), hash(page));
    await shot(page, 'r05_semana');
    await tap(page, 'Dia', { exact: true, touch: true, wait: 1800 });
    check('rotina: visao diaria', hash(page).includes('modo=dia'), hash(page));
    await tap(page, 'Alice', { contains: true, touch: true, wait: 1800 });
    check('rotina: troca de crianca mantem a visao', hash(page).startsWith('#/rotina/p5') && hash(page).includes('modo=dia') && (await waitText(page, 'Alice Exemplo Prado')), hash(page));
    await ctx.close();
  });

  await step('celular: rotina registro rapido e correcao', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/rotina/p1?vista=diario&perfil=responsavel');
    await waitText(page, 'Registrar agora');
    await shot(page, 'r06_diario_botoes_rapidos');
    await tap(page, 'Registrar Fralda', { touch: true });
    await tap(page, 'Xixi', { exact: true, touch: true, wait: 600 });
    await shot(page, 'r07_registro_fralda');
    await tap(page, 'Salvar', { exact: true, touch: true, wait: 1500 });
    const saved = (await labels(page)).match(/Registro salvo: Fralda às (\d\d:\d\d)/);
    check('diario: fralda registrada em 3 toques com horario', !!saved, saved ? saved[0] : '');
    check('diario: registro mostra o autor', await has(page, 'Informado pela família'), '');
    await shot(page, 'r08_fralda_salva');
    await tap(page, saved[1] + ' ', { contains: true, touch: true, wait: 1800 });
    check('diario: abre o registro com autor', (await waitText(page, 'Registro do diário')) && (await has(page, 'Autor')), hash(page));
    await tap(page, 'Corrigir', { exact: true, touch: true });
    check('diario: correcao abre o formulario', await waitText(page, 'Corrigir: Fralda'), '');
    await tap(page, 'Xixi e cocô', { touch: true, wait: 600 });
    await fill(page, 'Motivo da correção (opcional)', 'Toquei errado (teste e2e)', { touch: true });
    await tap(page, 'Salvar correção', { touch: true, wait: 1800 });
    const l = await labels(page);
    check('diario: correcao guarda versao anterior e motivo', l.includes('Corrigido por') && l.includes('Motivo: Toquei errado (teste e2e)') && l.includes('Antes:'), '');
    await shot(page, 'r09_correcao_historico');
    await nav(page, '#/rotina/p1?vista=diario');
    await tap(page, 'Registrar Mamada', { touch: true });
    await tap(page, 'Mamadeira', { touch: true, wait: 600 });
    await tap(page, '120 mL', { exact: true, touch: true, wait: 600 });
    await tap(page, 'Salvar', { exact: true, touch: true, wait: 1500 });
    check('diario: mamadeira com quantidade e unidade', await waitText(page, 'Registro salvo: Mamada'), '');
    await tap(page, 'Registrar Temperatura', { touch: true });
    await fill(page, 'Temperatura (°C)', '37,6', { touch: true });
    const [fc] = await Promise.all([page.waitForEvent('filechooser', { timeout: 15000 }), tap(page, 'Anexar foto ou arquivo', { touch: true, wait: 500 })]);
    await fc.setFiles({ name: 'termometro-exemplo.png', mimeType: 'image/png', buffer: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=', 'base64') });
    check('diario: foto anexada ao registro', await waitText(page, 'termometro-exemplo.png'), '');
    await shot(page, 'r10_temperatura_com_foto');
    await tap(page, 'Salvar', { exact: true, touch: true, wait: 1500 });
    check('diario: temperatura salva', await waitText(page, 'Registro salvo: Temperatura'), '');
    await ctx.close();
  });

  await step('celular: rotina compromisso criar editar concluir', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/rotina/p1?perfil=responsavel');
    await tap(page, 'Novo compromisso', { touch: true, wait: 1800 });
    check('compromisso: formulario aberto', await waitText(page, 'Título'), hash(page));
    await tap(page, 'Salvar', { exact: true, touch: true, wait: 1200 });
    check('compromisso: validacao visivel junto ao botao', await waitText(page, 'Informe um título.'), '');
    await shot(page, 'r11_validacao');
    const tomorrow = addDays(new Date(), 1);
    await tap(page, 'Consulta', { exact: true, touch: true, wait: 600 });
    await fill(page, 'Título', 'Dentista (exemplo e2e)', { touch: true });
    await fill(page, 'Data (dd/mm/aaaa)', dmy(tomorrow), { touch: true });
    await fill(page, 'Horário', '10:00', { touch: true });
    await tap(page, '1 hora antes', { touch: true, wait: 600 });
    await shot(page, 'r12_novo_compromisso');
    await tap(page, 'Salvar', { exact: true, touch: true, wait: 2000 });
    check('compromisso: criado e aberto no dia', hash(page).includes('modo=dia') && hash(page).includes('dia=' + dkey(tomorrow)) && (await waitText(page, 'Dentista (exemplo e2e)')), hash(page));
    check('compromisso: marcado como planejado e com lembrete', (await has(page, 'Planejado')) && (await has(page, 'Com lembrete')), '');
    await tap(page, 'Dentista (exemplo e2e)', { contains: true, touch: true });
    await tap(page, 'Editar', { exact: true, touch: true, wait: 1800 });
    check('compromisso: edicao abre', await waitText(page, 'Editar compromisso'), hash(page));
    await fill(page, 'Horário', '11:30', { touch: true });
    await tap(page, 'Salvar', { exact: true, touch: true, wait: 2000 });
    check('compromisso: horario editado', (await waitText(page, 'Compromisso atualizado.')) && (await has(page, '11:30')), '');
    await tap(page, 'Dentista (exemplo e2e)', { contains: true, touch: true });
    await tap(page, 'Lembretes', { exact: true, touch: true });
    await tap(page, '1 dia antes', { touch: true, wait: 600 });
    await tap(page, 'Salvar lembretes', { touch: true, wait: 1500 });
    check('compromisso: lembretes configurados', await waitText(page, 'Lembretes atualizados.'), '');
    await tap(page, 'Dentista (exemplo e2e)', { contains: true, touch: true });
    const sheet = await labels(page);
    check('compromisso: detalhe mostra os lembretes escolhidos', sheet.includes('1 hora antes') && sheet.includes('1 dia antes'), '');
    await shot(page, 'r13_detalhe_compromisso');
    await tap(page, 'Concluir', { exact: true, touch: true, wait: 1500 });
    check('compromisso: concluido aparece como realizado', (await waitText(page, 'Marcado como realizado.')) && (await has(page, 'Realizado')), '');
    await shot(page, 'r14_concluido');
    await tap(page, 'Dentista (exemplo e2e)', { contains: true, touch: true });
    await tap(page, 'Reabrir', { exact: true, touch: true, wait: 1500 });
    check('compromisso: reaberto', await waitText(page, 'Compromisso reaberto.'), '');
    await tap(page, 'Dentista (exemplo e2e)', { contains: true, touch: true });
    await tap(page, 'Cancelar compromisso', { touch: true, wait: 1000 });
    await fill(page, 'Motivo (opcional)', 'Remarcado (teste e2e)', { touch: true });
    await tap(page, 'Cancelar compromisso', { last: true, touch: true, wait: 1500 });
    check('compromisso: cancelado com motivo', (await waitText(page, 'Compromisso cancelado.')) && (await has(page, 'Cancelado')), '');
    await shot(page, 'r14b_cancelado');
    await ctx.close();
  });

  await step('celular: rotina lembrete no app', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/rotina/p1?perfil=responsavel');
    const at = new Date(Date.now() + 20 * 60000);
    await tap(page, 'Novo compromisso', { touch: true, wait: 1800 });
    await fill(page, 'Título', 'Dar vitamina (exemplo e2e)', { touch: true });
    await fill(page, 'Data (dd/mm/aaaa)', dmy(at), { touch: true });
    await fill(page, 'Horário', hm(at), { touch: true });
    await tap(page, 'Salvar', { exact: true, touch: true, wait: 2500 });
    check('lembrete: aviso aparece no app no horario do lembrete', await waitText(page, 'Lembrete: Dar vitamina (exemplo e2e)', 25000), '');
    await shot(page, 'r15_lembrete_no_app');
    await nav(page, '#/rotina/p1?vista=diario&dia=' + dkey(addDays(new Date(), -3)));
    await tap(page, 'Ver', { exact: true, touch: true, wait: 1800 });
    check('lembrete: Ver abre o dia do compromisso', hash(page).includes('modo=dia') && hash(page).includes('dia=' + dkey(at)), hash(page));
    await tap(page, 'Dispensar', { exact: true, touch: true, wait: 1200 });
    check('lembrete: dispensado some da barra', !(await has(page, 'Lembrete: Dar vitamina (exemplo e2e)')), '');
    await ctx.close();
  });

  await step('celular: rotina resumo para o pediatra', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await ctx.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: new URL(BASE).origin });
    await open(page, '#/rotina/p1?perfil=responsavel');
    await tap(page, 'Resumo para o pediatra', { touch: true, wait: 1800 });
    check('resumo: abre pelo botao da rotina', hash(page).endsWith('/rotina/p1/resumo') && (await waitText(page, 'Prévia')), hash(page));
    await shot(page, 'r16_resumo_previa');
    const copyText = async () => { await tap(page, 'Copiar texto', { touch: true, wait: 1200 }); return page.evaluate(() => navigator.clipboard.readText()).catch((e) => 'ERRO ' + e); };
    const all = await copyText();
    check('resumo: identifica a crianca e que foi informado pela familia', all.includes('Resumo da rotina - Luna Exemplo Souza') && all.includes('Informado pela família') && all.includes('Mamadas:'), all.slice(0, 60));
    await tap(page, 'Limpar', { exact: true, touch: true, wait: 800 });
    await tap(page, 'Fralda', { exact: true, touch: true, wait: 1200 });
    const only = await copyText();
    check('resumo: filtro por tipo muda o resumo', only.includes('Fraldas:') && !only.includes('Mamadas:'), '');
    await fill(page, 'Mensagem para o pediatra (opcional)', 'Dúvida sobre o sono (exemplo e2e)', { touch: true });
    await tap(page, 'Enviar ao pediatra', { touch: true, wait: 1500 });
    check('resumo: enviado ao pediatra', await waitText(page, 'Resumo enviado ao pediatra'), '');
    await shot(page, 'r17_resumo_enviado');
    const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 20000 }), tap(page, 'Baixar PDF', { touch: true, wait: 800 })]);
    const pdf = await pdfFromDownload(dl);
    check('resumo: PDF baixado', pdf.magic === '%PDF-' && pdf.name.startsWith('resumo-rotina-luna-'), pdf.name + ' ' + pdf.size + ' bytes');
    await page.waitForTimeout(2500);
    const copied = await copyText();
    check('resumo: texto copiado para compartilhar', copied.includes('Resumo da rotina - Luna Exemplo Souza') && copied.includes('Fraldas:'), copied.split('\n')[0]);
    await tap(page, 'Compartilhar a rotina com a clínica', { touch: true, wait: 1200 });
    check('resumo: sem consentimento nao envia', await isDisabled(page, 'Enviar ao pediatra'), '');
    await ctx.close();
  });

  await step('celular: rotina visao do profissional', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/pacientes/p1?perfil=profissional');
    await tap(page, 'Resumos enviados pela família', { touch: true, wait: 1800 });
    check('profissional: lista de resumos enviados pela familia', await waitText(page, 'Enviado por'), hash(page));
    await tap(page, 'Enviado por', { contains: true, touch: true, wait: 1800 });
    const l = await labels(page);
    check('profissional: resumo identificado como informado pela familia', l.includes('Resumo enviado') && l.includes('Informado pela família') && l.includes('Mensagem da família'), '');
    await shot(page, 'r18_profissional_resumo');
    await nav(page, '#/rotina/p1?vista=diario');
    await waitText(page, 'Linha do tempo');
    const d = await labels(page);
    check('profissional: diario somente leitura com origem clara', d.includes('Informado pela família. Calendário e diário') && !d.includes('Registrar Mamada') && !d.includes('Novo compromisso'), '');
    await shot(page, 'r19_profissional_diario');
    await ctx.close();
  });

  await step('celular: rotina protecao dos dados', async () => {
    const cases = [
      ['profissional', '#/rotina/p5', 'Rotina não compartilhada'],
      ['profissional', '#/rotina/p1/evento/novo', 'Acesso restrito'],
      ['profissional', '#/rotina/p1/resumo', 'Acesso restrito'],
      ['recepcao', '#/rotina/p1', 'Acesso restrito'],
      ['financeiro', '#/rotina/p1', 'Acesso restrito'],
      ['administrador', '#/rotina/p1/registro/rs1', 'Acesso restrito'],
      ['responsavel', '#/rotina/p2', 'Criança não encontrada'],
    ];
    for (const [perfil, route, expected] of cases) {
      const { ctx, page } = await newPage(browser, MOBILE);
      const sep = route.includes('?') ? '&' : '?';
      await open(page, route + sep + 'perfil=' + perfil);
      check('rotina protegida: ' + perfil + ' em ' + route, await waitText(page, expected), expected);
      if (perfil === 'profissional' && route === '#/rotina/p5') await shot(page, 'r20_nao_compartilhada');
      await ctx.close();
    }
  });

  // ---------- Meus modelos de receita ----------
  const fmtBr = (v, d) => {
    let s = v.toFixed(d);
    if (s.includes('.')) s = s.replace(/0+$/, '').replace(/\.$/, '');
    return s.replace('.', ',');
  };
  const weightOf = async (page) => {
    const m = (await labels(page)).match(/(\d+(?:,\d+)?) kg em \d\d\/\d\d\/\d{4}/);
    return m ? m[1] : null;
  };
  const doseA = (w) => {
    const kg = parseFloat(w.replace(',', '.'));
    const mg = 15 * kg;
    return fmtBr(mg / 20, 1) + ' mL (' + fmtBr(mg, 2) + ' mg) por dose';
  };
  const CHECKS = ['Medicamento: ', 'Apresenta\u00e7\u00e3o: ', 'Concentra\u00e7\u00e3o: ', 'Dose: ', 'Volume: ', 'Via: ', 'Frequ\u00eancia: ', 'Dura\u00e7\u00e3o: ', 'Quantidade: '];
  let emittedDoc = null;

  await step('computador: modelos lista busca duplicar editar', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/modelos-receita?perfil=profissional');
    const l0 = [await waitText(page, 'Meus modelos de receita'), await has(page, 'Febre - Medicamento Exemplo A'), await has(page, 'Suplemento D + lavagem nasal')];
    check('modelos: lista com os modelos de exemplo', l0.every(Boolean), l0.join('/'));
    await shot(page, 'mr01_lista');
    await fill(page, 'Buscar modelo', 'solucao nasal');
    await page.waitForTimeout(800);
    const b1 = [await has(page, 'Suplemento D + lavagem nasal'), !(await has(page, 'Febre - Medicamento Exemplo A'))];
    check('modelos: busca sem acento acha pelo medicamento', b1.every(Boolean), b1.join('/'));
    await shot(page, 'mr02_busca');
    await fill(page, 'Buscar modelo', 'tosse');
    check('modelos: busca sem resultado', await waitText(page, 'Nenhum modelo encontrado.'), '');
    await fill(page, 'Buscar modelo', 'febre');
    await tap(page, 'Duplicar', { wait: 2200 });
    const e1 = [await waitText(page, 'Editar modelo de receita'), /\/modelos-receita\/m\d+\/editar/.test(hash(page)) && !hash(page).includes('/m1/')];
    check('modelos: duplicar abre a copia para editar', e1.every(Boolean), e1.join('/'));
    await fill(page, 'Nome do modelo *', 'Febre - revisado (e2e)');
    await fill(page, 'O que mudou', 'Nome ajustado no teste');
    await shot(page, 'mr03_editor_copia');
    await tap(page, 'Salvar modelo', { wait: 2200 });
    await fill(page, 'Buscar modelo', 'revisado');
    const s1 = [await waitText(page, 'Febre - revisado (e2e)'), await has(page, 'v2 \u00b7 1 item')];
    check('modelos: edicao salva como versao 2', s1.every(Boolean), s1.join('/'));
    await fill(page, 'Buscar modelo', 'febre');
    const s2 = [await waitText(page, 'Febre - revisado (e2e)'), await has(page, 'Febre - Medicamento Exemplo A'), await has(page, 'v1 \u00b7 1 item')];
    check('modelos: original continua na v1 ao lado da copia', s2.every(Boolean), s2.join('/'));

    await nav(page, '#/modelos-receita/novo');
    await fill(page, 'Nome do modelo *', 'Modelo novo (e2e)');
    await tap(page, 'Adicionar item');
    await choose(page, 'Refer\u00eancia de dose *', 'Medicamento Exemplo B');
    await choose(page, 'Apresenta\u00e7\u00e3o *', 'Suspens\u00e3o 250 mg/5 mL');
    check('modelos: item pelo peso usa a frequencia da referencia', await waitText(page, 'Frequ\u00eancia da refer\u00eancia: de 12/12h'), '');
    await fill(page, 'Dura\u00e7\u00e3o *', '7 dias');
    await fill(page, 'Quantidade', '1 frasco');
    await shot(page, 'mr04_item_pelo_peso');
    await tap(page, 'Salvar item', { wait: 1500 });
    check('modelos: item guarda so mg/kg, recalculado por paciente', await waitText(page, '40 mg/kg/dia, recalculada com o peso de cada paciente'), '');
    await tap(page, 'Salvar modelo', { wait: 2200 });
    check('modelos: novo modelo aparece na lista', await waitText(page, 'Modelo novo (e2e)'), '');
    await ctx.close();
  });

  await step('computador: modelo na consulta ate a emissao', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p5/consulta/c2?etapa=documentos&perfil=profissional');
    await tap(page, 'Receita a partir de modelo', { wait: 1500 });
    check('consulta: escolha de modelo abre durante a consulta', await waitText(page, 'Escolher modelo de receita'), '');
    await shot(page, 'mr05_escolher_modelo');
    await tap(page, 'Febre - Medicamento Exemplo A', { wait: 2500 });
    await waitText(page, 'Editar: Receitu\u00e1rio');
    const w = await weightOf(page);
    const l1 = await labels(page);
    const dose = w ? doseA(w) : '?';
    check('consulta: rascunho novo com o paciente atual', l1.includes('Alice Exemplo Prado') && hash(page).includes('/pacientes/p5/documentos/'), hash(page));
    check('consulta: dose refeita com o peso atual (' + w + ' kg)', !!w && l1.includes(dose) && l1.includes('15 mg/kg/dose \u00d7 ' + w + ' kg'), dose);
    check('consulta: exige conferencia dos nove campos', l1.includes('Confer\u00eancia do item (0 de 9)'), '');
    await shot(page, 'mr06_rascunho_conferencia');
    await tap(page, 'Salvar e revisar', { wait: 2000 });
    const l2 = await labels(page);
    const reviewOff = await isDisabled(page, 'Revisei o conte\u00fado');
    check('consulta: sem conferencia nao revisa nem emite', l2.includes('confira medicamento, apresenta\u00e7\u00e3o') && reviewOff === true && !l2.includes('Emitir documento'), 'revisaoDesabilitada=' + reviewOff);
    await shot(page, 'mr07_bloqueado_sem_conferencia');
    const docPath = hash(page).replace(/^#/, '').split('?')[0];
    emittedDoc = docPath;
    await tap(page, 'Editar', { exact: true, wait: 2200 });
    for (const c of CHECKS) await tap(page, c, { wait: 500 });
    check('consulta: item conferido (9 de 9)', await waitText(page, 'Confer\u00eancia do item (9 de 9)'), '');
    await shot(page, 'mr08_item_conferido');

    await tap(page, 'Adicionar item manualmente');
    const vals = [['Medicamento *', 'Solu\u00e7\u00e3o Exemplo G (fict\u00edcia)'], ['Apresenta\u00e7\u00e3o e concentra\u00e7\u00e3o *', 'Solu\u00e7\u00e3o oral'], ['Concentra\u00e7\u00e3o', '1 mg/mL'], ['Dose por administra\u00e7\u00e3o *', '2 mL'], ['Volume por dose', '2 mL'], ['Intervalo *', '1 vez ao dia'], ['Dura\u00e7\u00e3o *', '5 dias'], ['Quantidade', '1 frasco']];
    for (const [f, v] of vals) await fill(page, f, v, { last: true });
    await tap(page, 'Salvar item', { wait: 1500 });
    check('consulta: segundo item tambem exige conferencia', await waitText(page, 'Confer\u00eancia do item (0 de 9)'), '');
    const item2 = ['Medicamento: Solu\u00e7\u00e3o Exemplo G', 'Apresenta\u00e7\u00e3o: Solu\u00e7\u00e3o oral', 'Concentra\u00e7\u00e3o: 1 mg/mL', 'Dose: 2 mL', 'Volume: 2 mL', 'Via: via oral', 'Frequ\u00eancia: 1 vez ao dia', 'Dura\u00e7\u00e3o: 5 dias', 'Quantidade: 1 frasco'];
    for (const c of item2) await tap(page, c, { last: true, wait: 500 });
    await fill(page, 'Orienta\u00e7\u00f5es gerais', 'Oferecer l\u00edquidos. Retorno em 7 dias (e2e).');
    const l3 = await labels(page);
    check('consulta: dois itens conferidos e orientacoes editadas', (l3.match(/Confer\u00eancia do item \(9 de 9\)/g) || []).length === 2 && !l3.includes('Pend\u00eancias para revisar'), '');
    await shot(page, 'mr09_dois_itens_conferidos');
    await tap(page, 'Salvar e revisar', { wait: 2000 });
    await tap(page, 'Revisei o conte\u00fado');
    await tap(page, 'Marcar como revisado');
    await tap(page, 'Emitir documento', { wait: 1800 });
    const l4 = await labels(page);
    check('consulta: receita emitida com origem no modelo v1', l4.includes('Emitido') && l4.includes('Modelo "Febre - Medicamento Exemplo A" \u00b7 v1') && l4.includes(dose) && l4.includes('Retorno em 7 dias (e2e)'), '');
    await shot(page, 'mr10_receita_emitida');

    await page.waitForTimeout(4500);
    const [popup] = await Promise.all([ctx.waitForEvent('page', { timeout: 15000 }), tap(page, 'Visualizar PDF', { wait: 800 })]);
    const vu = popup.url();
    const vm = vu.startsWith('blob:') ? await blobMagic(page, vu) : null;
    check('consulta: visualizar abre o PDF em outra aba', !!vm && vm.magic === '%PDF-', vu.slice(0, 40) + ' ' + (vm && vm.size));
    await popup.close();
    await page.waitForTimeout(3500);
    const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 15000 }), tap(page, 'Gerar PDF', { wait: 800 })]);
    const pdf = await pdfFromDownload(dl);
    check('consulta: PDF da receita baixado', pdf.magic === '%PDF-' && pdf.name.startsWith('receituario-alice-v1'), pdf.name + ' ' + pdf.size + ' bytes');
    fs.copyFileSync(await dl.path(), path.join(OUT, pdf.name));
    await page.waitForTimeout(3500);
    await tap(page, 'Imprimir', { wait: 1500 });
    const src = await page.evaluate(() => document.getElementById('p360-print-frame')?.src || null);
    const pm = src ? await blobMagic(page, src) : null;
    await page.waitForTimeout(1200);
    const printed = await page.evaluate(() => window.__printCalled || 0);
    check('consulta: imprimir carrega o PDF e chama print()', !!pm && pm.magic === '%PDF-' && printed > 0, 'print() ' + printed + 'x');

    await tap(page, 'Voltar \u00e0 consulta', { wait: 2200 });
    const l5 = await labels(page);
    check('consulta: receita emitida no historico da consulta', l5.includes('Documentos desta consulta') && l5.includes('Receitu\u00e1rio') && l5.includes('Emitido'), '');
    await shot(page, 'mr11_historico_consulta');

    await nav(page, '#/modelos-receita/m1/editar');
    await fill(page, 'Orienta\u00e7\u00f5es gerais', 'Orienta\u00e7\u00e3o alterada depois (e2e).');
    await tap(page, 'Salvar modelo', { wait: 2200 });
    await nav(page, '#' + emittedDoc);
    await waitText(page, 'Modelo de origem');
    const l6 = await labels(page);
    check('modelo editado depois nao muda a receita emitida', l6.includes('Retorno em 7 dias (e2e)') && !l6.includes('Orienta\u00e7\u00e3o alterada depois') && l6.includes('\u00b7 v1') && l6.includes(dose), '');
    await shot(page, 'mr12_emitida_intacta');
    await ctx.close();
  });

  await step('celular: modelos para outras criancas', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/modelos-receita?paciente=p4&perfil=profissional');
    await fill(page, 'Buscar modelo', 'febre', { touch: true });
    await tap(page, 'Usar para Davi', { touch: true, wait: 2500 });
    await waitText(page, 'Editar: Receitu\u00e1rio');
    const w = await weightOf(page);
    const l1 = await labels(page);
    check('celular: outra crianca, dose com o peso dela (' + w + ' kg)', !!w && l1.includes(doseA(w)) && l1.includes('Davi Exemplo Nunes'), w ? doseA(w) : '');
    check('celular: alerta de volume exige ciencia', l1.includes('Alertas:') && l1.includes('Confer\u00eancia do item (0 de 10)'), '');
    await shot(page, 'mr13_celular_outra_crianca');

    await open(page, '#/modelos-receita?paciente=p3&perfil=profissional');
    await fill(page, 'Buscar modelo', 'febre', { touch: true });
    await tap(page, 'Usar para Maya', { touch: true, wait: 2500 });
    await waitText(page, 'Editar: Receitu\u00e1rio');
    let l2 = await labels(page);
    for (const want of ['Dose n\u00e3o calculada', 'Dose: n\u00e3o informado']) {
      await scrollTo(page, want);
      l2 += ' | ' + await labels(page);
    }
    check('celular: sem peso, nenhuma dose copiada e calculo bloqueado', l2.includes('Dose n\u00e3o calculada') && l2.includes('Peso n\u00e3o registrado') && l2.includes('Dose: n\u00e3o informado'), '');
    await shot(page, 'mr14_celular_sem_peso');

    await open(page, '#/pacientes/p1/documentos/d3?perfil=profissional');
    await tap(page, 'Salvar como modelo', { touch: true });
    await fill(page, 'Nome do modelo *', 'Da receita da Luna (e2e)', { touch: true });
    await tap(page, 'Salvar modelo', { last: true, touch: true, wait: 1500 });
    await nav(page, '#/modelos-receita');
    await fill(page, 'Buscar modelo', 'Luna', { touch: true });
    const l3 = await labels(page);
    check('celular: receita salva como modelo sem a dose da crianca', l3.includes('Da receita da Luna (e2e)') && l3.includes('Dose a definir na consulta') && !l3.includes('5 mL') && !l3.includes('2 gotas'), '');
    await shot(page, 'mr15_celular_modelo_da_receita');
    await ctx.close();

    const r = await newPage(browser, MOBILE);
    await open(r.page, '#/modelos-receita?perfil=recepcao');
    check('modelos protegidos: recepcao nao acessa', await waitText(r.page, 'Acesso restrito'), '');
    await r.ctx.close();
  });

  // ------------------------------------------------ Logomarca por conta
  const LOGO_A = 'logo-clinica-exemplo.png';
  const LOGO_A2 = 'logo-clinica-exemplo-v2.jpg';
  const DEFAULT_HEADER = 'Cabe\u00e7alho do documento: Identidade padr\u00e3o do Pediatria360';
  const headerWith = (file) => 'Cabe\u00e7alho do documento: Logomarca da conta (' + file;

  async function sendLogo(page, button, file, opts = {}) {
    const [fc] = await Promise.all([page.waitForEvent('filechooser', { timeout: 15000 }), tap(page, button, { wait: 500, touch: opts.touch })]);
    await fc.setFiles(file);
    await page.waitForTimeout(2500);
  }

  async function shotPdf(ctx, page, button, name, opts = {}) {
    const [popup] = await Promise.all([ctx.waitForEvent('page', { timeout: 15000 }), tap(page, button, { wait: 800, touch: opts.touch })]);
    const url = popup.url();
    const info = url.startsWith('blob:') ? await blobImageInfo(page, url) : null;
    await popup.waitForTimeout(3000);
    await popup.screenshot({ path: path.join(OUT, name + '.png') }).catch(() => {});
    await popup.close();
    await page.waitForTimeout(1500);
    return info;
  }

  await step('computador: logomarca enviar visualizar trocar remover', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/inicio?perfil=profissional');
    const pngA = await makeLogo(page, { text: 'Cl\u00ednica Exemplo A' });
    check('logomarca: sem cadastro o painel usa a identidade padrao', await waitText(page, 'Sem logomarca: painel e documentos usam a identidade padr\u00e3o do Pediatria360.'), '');
    await shot(page, 'lg01_painel_padrao');
    await tap(page, 'Cadastrar logomarca', { wait: 2000 });
    check('logomarca: configuracao no perfil', (hash(page) === '#/perfil/logomarca') && (await waitText(page, 'Nenhuma logomarca cadastrada')), hash(page));
    await shot(page, 'lg02_sem_logomarca');

    await sendLogo(page, 'Enviar logomarca', { name: 'logo-disfarcado.png', mimeType: 'image/png', buffer: Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>') });
    check('logomarca: arquivo que nao e imagem e recusado pelo conteudo', (await waitText(page, 'Formato n\u00e3o aceito')) && (await has(page, 'Nenhuma logomarca cadastrada')), '');
    await shot(page, 'lg03_arquivo_recusado');

    await sendLogo(page, 'Enviar logomarca', { name: LOGO_A, mimeType: 'image/png', buffer: pngA });
    check('logomarca: previa antes de salvar', (await waitText(page, 'Usar esta logomarca?')) && (await has(page, 'Como fica no cabe\u00e7alho')), '');
    await shot(page, 'lg04_confirmar_envio');
    await tap(page, 'Salvar logomarca', { wait: 1500 });
    const l1 = await labels(page);
    check('logomarca: enviada e salva', l1.includes('Logomarca salva') && l1.includes(LOGO_A) && l1.includes('600 x 200 px'), '');
    await shot(page, 'lg05_logomarca_salva');
    await tap(page, 'Visualizar', { exact: true, wait: 1200 });
    check('logomarca: visualizar ampliada', await waitText(page, 'Logomarca da conta em tamanho ampliado'), '');
    await shot(page, 'lg06_visualizar');
    await tap(page, 'Fechar', { wait: 800 });
    await page.waitForTimeout(3000);
    const ex = await shotPdf(ctx, page, 'Ver PDF de exemplo', 'lg07_pdf_exemplo');
    check('logomarca: PDF de exemplo com a imagem', !!ex && ex.magic === '%PDF-' && ex.image && ex.widths.includes(600), ex ? 'larguras ' + ex.widths.join(',') : 'sem PDF');

    await nav(page, '#/inicio');
    check('logomarca: aparece no painel', await waitText(page, 'Painel de Consult\u00f3rio Exemplo (fict\u00edcio): Logomarca da conta (' + LOGO_A), '');
    check('logomarca: telas gerais mantem a identidade do app', await has(page, 'Pedi360'), '');
    await shot(page, 'lg08_painel_com_logomarca');

    // Todos os tipos de documento, com a imagem no PDF e na impressao.
    let emitted = null;
    for (const d of DOCS) {
      await nav(page, '#/pacientes/p2/documentos/novo?tipo=' + d.slug);
      await waitText(page, 'Novo: ' + d.label);
      for (const [f, v] of d.fields) await fill(page, f, v);
      if (d.slug === 'receituario') {
        await tap(page, 'Adicionar item manualmente');
        const vals = [['Medicamento *', 'Medicamento Exemplo A'], ['Apresenta\u00e7\u00e3o e concentra\u00e7\u00e3o *', 'Suspens\u00e3o 100 mg/5 mL'], ['Dose por administra\u00e7\u00e3o *', '5 mL'], ['Intervalo *', 'de 8/8h'], ['Dura\u00e7\u00e3o *', '3 dias']];
        for (const [f, v] of vals) await fill(page, f, v, { last: true });
        await tap(page, 'Salvar item');
      }
      await tap(page, 'Salvar e revisar', { wait: 1500 });
      await waitText(page, 'Marcar como revisado', 8000);
      const draftHeader = await has(page, headerWith(LOGO_A));
      await tap(page, 'Revisei o conte\u00fado');
      await tap(page, 'Marcar como revisado');
      await tap(page, 'Emitir documento', { wait: 1800 });
      const issuedHeader = await has(page, headerWith(LOGO_A));
      if (d.slug === 'receituario') { emitted = hash(page); await shot(page, 'lg09_receita_emitida_com_logomarca'); }
      await page.waitForTimeout(4000);
      const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 15000 }), tap(page, 'Gerar PDF', { wait: 800 })]);
      const info = pdfImageInfo(fs.readFileSync(await dl.path()));
      fs.copyFileSync(await dl.path(), path.join(OUT, 'logo_' + dl.suggestedFilename()));
      await page.waitForTimeout(3500);
      await tap(page, 'Imprimir', { wait: 1500 });
      const src = await page.evaluate(() => document.getElementById('p360-print-frame')?.src || null);
      const pi = src ? await blobImageInfo(page, src) : null;
      check('logomarca: ' + d.label + ' - cabecalho na tela, no PDF e na impressao', draftHeader && issuedHeader && info.image && info.widths.includes(600) && !!pi && pi.image && pi.widths.includes(600), 'pdf ' + info.widths.join(',') + ' / impressao ' + (pi ? pi.widths.join(',') : '-'));
    }
    const rxPdf = await shotPdf(ctx, page, 'Visualizar PDF', 'lg10_pdf_receita_com_logomarca');
    check('logomarca: visualizar PDF da receita', !!rxPdf && rxPdf.image, '');

    await nav(page, '#/pacientes/p1/crescimento');
    await waitText(page, 'Exportar PDF', 15000);
    await page.waitForTimeout(3000);
    const [gdl] = await Promise.all([page.waitForEvent('download', { timeout: 20000 }), tap(page, 'Exportar PDF', { wait: 800 })]);
    const gi = pdfImageInfo(fs.readFileSync(await gdl.path()));
    fs.copyFileSync(await gdl.path(), path.join(OUT, 'logo_' + gdl.suggestedFilename()));
    check('logomarca: relatorio de curvas com a imagem', gi.image && gi.widths.includes(600), gi.widths.join(','));
    await page.waitForTimeout(3000);

    await nav(page, '#/perfil/logomarca');
    const jpgA2 = await makeLogo(page, { w: 500, h: 250, text: 'Exemplo A (nova)', color: '#8A3FFC', type: 'image/jpeg' });
    await sendLogo(page, 'Trocar logomarca', { name: LOGO_A2, mimeType: 'image/jpeg', buffer: jpgA2 });
    check('logomarca: trocar pede confirmacao', await waitText(page, 'Trocar a logomarca?'), '');
    await tap(page, 'Salvar logomarca', { wait: 1500 });
    const l2 = await labels(page);
    check('logomarca: trocada (JPG)', l2.includes('Logomarca trocada') && l2.includes(LOGO_A2) && l2.includes('500 x 250 px'), '');
    await shot(page, 'lg11_logomarca_trocada');

    await nav(page, emitted);
    await waitText(page, 'Cabe\u00e7alho gravado na emiss\u00e3o');
    const l3 = await labels(page);
    await page.waitForTimeout(3000);
    const [edl] = await Promise.all([page.waitForEvent('download', { timeout: 15000 }), tap(page, 'Gerar PDF', { wait: 800 })]);
    const ei = pdfImageInfo(fs.readFileSync(await edl.path()));
    check('logomarca: emitido mantem a logomarca da emissao (tela e PDF)', l3.includes(headerWith(LOGO_A)) && !l3.includes(headerWith(LOGO_A2)) && ei.widths.includes(600) && !ei.widths.includes(500), ei.widths.join(','));
    await shot(page, 'lg12_emitido_mantem_logomarca');
    await page.waitForTimeout(3000);

    await nav(page, '#/pacientes/p2/documentos/novo?tipo=orientacoes');
    await fill(page, 'T\u00edtulo *', 'Depois da troca');
    await fill(page, 'Orienta\u00e7\u00f5es *', 'Texto fict\u00edcio.');
    await tap(page, 'Salvar e revisar', { wait: 1500 });
    check('logomarca: novo documento usa a logomarca nova', await waitText(page, headerWith(LOGO_A2)), '');

    await nav(page, '#/perfil/logomarca');
    await tap(page, 'Remover', { exact: true, wait: 1000 });
    check('logomarca: remover pede confirmacao', await waitText(page, 'Remover logomarca?'), '');
    await shot(page, 'lg13_remover_confirmacao');
    await tap(page, 'Remover', { exact: true, last: true, wait: 1500 });
    check('logomarca: removida volta a identidade padrao', (await waitText(page, 'Logomarca removida')) && (await has(page, 'Nenhuma logomarca cadastrada')), '');
    await nav(page, '#/inicio');
    check('logomarca: painel volta ao padrao', await waitText(page, 'Sem logomarca: painel e documentos usam'), '');
    await nav(page, emitted);
    check('logomarca: emitido continua com a logomarca da emissao apos remover', await waitText(page, headerWith(LOGO_A)), '');
    await nav(page, '#/pacientes/p2/documentos/novo?tipo=atestado');
    await tap(page, 'Salvar e revisar', { wait: 1500 });
    await waitText(page, 'Marcar como revisado', 8000);
    await page.waitForTimeout(3000);
    const [ndl] = await Promise.all([page.waitForEvent('download', { timeout: 15000 }), tap(page, 'Gerar PDF', { wait: 800 })]);
    const ni = pdfImageInfo(fs.readFileSync(await ndl.path()));
    check('logomarca: sem logomarca o PDF usa a identidade padrao', (await has(page, DEFAULT_HEADER)) && !ni.image, '');
    await shot(page, 'lg14_documento_identidade_padrao');
    await ctx.close();
  });

  await step('computador: logomarca so da propria conta', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/perfil/logomarca?perfil=profissional');
    await sendLogo(page, 'Enviar logomarca', { name: LOGO_A, mimeType: 'image/png', buffer: await makeLogo(page, { text: 'Cl\u00ednica Exemplo A' }) });
    await tap(page, 'Salvar logomarca', { wait: 1500 });
    await nav(page, '#/perfil');
    await tap(page, 'Trocar de conta', { wait: 1000 });
    await tap(page, 'Dr. Exemplo Colega', { wait: 1500 });
    check('conta: troca para a segunda conta ficticia', await waitText(page, 'Conta em uso: Dr. Exemplo Colega.'), '');
    await nav(page, '#/inicio');
    const l1 = await labels(page);
    check('conta: painel da outra conta sem a logomarca da primeira', l1.includes('Cl\u00ednica Exemplo Dois (fict\u00edcia)') && l1.includes('Sem logomarca') && !l1.includes(LOGO_A), '');
    await shot(page, 'lg15_outra_conta_painel');
    await nav(page, '#/perfil/logomarca');
    check('conta: configuracao da outra conta vazia', (await waitText(page, 'Nenhuma logomarca cadastrada')) && !(await has(page, LOGO_A)), '');
    await nav(page, '#/pacientes/p1/documentos/d1');
    check('conta: documento da primeira conta nao abre', await waitText(page, 'Registro n\u00e3o encontrado'), '');
    await shot(page, 'lg16_outra_conta_documento');
    await nav(page, '#/pacientes/p7/documentos/novo?tipo=orientacoes');
    await fill(page, 'T\u00edtulo *', 'Da segunda conta');
    await fill(page, 'Orienta\u00e7\u00f5es *', 'Texto fict\u00edcio.');
    await tap(page, 'Salvar e revisar', { wait: 1500 });
    await waitText(page, 'Marcar como revisado', 8000);
    const l2 = await labels(page);
    await page.waitForTimeout(3000);
    const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 15000 }), tap(page, 'Gerar PDF', { wait: 800 })]);
    const i2 = pdfImageInfo(fs.readFileSync(await dl.path()));
    check('conta: documento da segunda conta sem a logomarca da primeira', l2.includes(DEFAULT_HEADER) && l2.includes('Cl\u00ednica Exemplo Dois') && !i2.image, '');
    await ctx.close();

    for (const perfil of ['recepcao', 'financeiro', 'responsavel']) {
      const r = await newPage(browser, DESKTOP);
      await open(r.page, '#/perfil/logomarca?perfil=' + perfil);
      check('conta: ' + perfil + ' nao cadastra logomarca', await waitText(r.page, 'Acesso restrito'), '');
      await r.ctx.close();
    }
  });

  await step('celular: logomarca no painel e nos documentos', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/perfil/logomarca?perfil=profissional');
    await sendLogo(page, 'Enviar logomarca', { name: LOGO_A, mimeType: 'image/png', buffer: await makeLogo(page, { text: 'Cl\u00ednica Exemplo A' }) }, { touch: true });
    await shot(page, 'lg17_celular_confirmar');
    await tap(page, 'Salvar logomarca', { touch: true, wait: 1500 });
    check('celular: logomarca enviada pelo toque', await waitText(page, 'Logomarca salva'), '');
    await shot(page, 'lg18_celular_logomarca');
    await nav(page, '#/inicio');
    check('celular: logomarca no painel', await waitText(page, 'Logomarca da conta (' + LOGO_A), '');
    await shot(page, 'lg19_celular_painel');
    await nav(page, '#/pacientes/p1/documentos/d2');
    check('celular: cabecalho do documento com a logomarca', await waitText(page, headerWith(LOGO_A)), '');
    await shot(page, 'lg20_celular_documento');
    await page.waitForTimeout(3000);
    const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 15000 }), tap(page, 'Gerar PDF', { touch: true, wait: 800 })]);
    const i = pdfImageInfo(fs.readFileSync(await dl.path()));
    check('celular: PDF com a logomarca', i.image && i.widths.includes(600), i.widths.join(','));
    await ctx.close();
  });

  // ------------------------------------------------ Sono e puericultura
  const two = (n) => String(n).padStart(2, '0');
  const dm = (d) => two(d.getDate()) + '/' + two(d.getMonth() + 1);
  const ymd = (d) => d.getFullYear() + '-' + two(d.getMonth() + 1) + '-' + two(d.getDate());
  const daysFrom = (n) => { const d = new Date(); d.setHours(12, 0, 0, 0); d.setDate(d.getDate() + n); return d; };
  const monthsFrom = (m) => { const t = new Date(); return new Date(t.getFullYear(), t.getMonth() + m, t.getDate(), 12); };

  // Toca na primeira opcao presente (rotulo com ou sem dica acessivel).
  async function tapAny(page, options, opts = {}) {
    for (const [label, o] of options) {
      if (await find(page, label, { ...opts, ...o })) { await tap(page, label, { ...opts, ...o }); return label; }
    }
    throw new Error('nenhuma opcao: ' + options.map((x) => x[0]).join(' / '));
  }

  async function downloadPdf(page, button, opts = {}) {
    await page.waitForTimeout(3000);
    const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 20000 }), tap(page, button, { wait: 800, touch: opts.touch })]);
    const buf = fs.readFileSync(await dl.path());
    if (opts.keep) fs.copyFileSync(await dl.path(), path.join(OUT, opts.keep + '_' + dl.suggestedFilename()));
    return { ...pdfImageInfo(buf), name: dl.suggestedFilename() };
  }

  await step('celular: sono familia registra, corrige e resume', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/rotina/p5?vista=sono&perfil=responsavel');
    const l0 = await labels(page);
    check('sono familia: registrar, resumo da semana e linha do tempo', ['Registrar sono', 'Resumo da semana', 'Linha do tempo', 'Dormiu agora (noite)'].every((x) => l0.includes(x)), '');
    await shot(page, 'sp01_sono_familia');

    const d2 = daysFrom(-2);
    await tap(page, dm(d2) + ': ', { contains: true, touch: true });
    await tap(page, 'Cochilo', { touch: true, wait: 1500 });
    await fill(page, 'Início', '14:00');
    await fill(page, 'Fim (HH:MM)', '15:10');
    await fill(page, 'Despertou às', '14:30');
    await fill(page, 'Minutos acordado', '5');
    await tap(page, 'Incluir', { exact: true, touch: true });
    check('sono familia: despertar incluido no cochilo', await waitText(page, 'Despertou às 14:30 (5 min)'), '');
    await shot(page, 'sp02_cochilo_com_despertar');
    await tap(page, 'Salvar', { exact: true, last: true, touch: true, wait: 1800 });

    await tap(page, 'Noite com horários', { touch: true, wait: 1500 });
    await fill(page, 'Início', '20:30');
    await fill(page, 'Fim (HH:MM)', '06:10');
    await fill(page, 'Despertou às', '01:40');
    await fill(page, 'Minutos acordado', '15');
    await tap(page, 'Incluir', { exact: true, touch: true });
    await tap(page, 'Salvar', { exact: true, last: true, touch: true, wait: 1800 });
    const row = dm(d2) + ': noite 9h40 com 1 despertar - 1 cochilo (1h10) - total 10h50';
    check('sono familia: noite com despertar e cochilo no resumo do dia', await waitText(page, row), '');
    const l1 = await labels(page);
    check('sono familia: resumo da semana com as medias', l1.includes('Resumo da semana') && /m[eé]dia/i.test(l1), '');
    await shot(page, 'sp03_linha_do_tempo_resumo');

    await tap(page, 'Dormiu agora (noite)', { touch: true, wait: 1500 });
    check('sono familia: sono em andamento', await waitText(page, 'Sono noturno desde'), '');
    await tap(page, 'Despertar', { exact: true, touch: true, wait: 1200 });
    await tap(page, '10 min', { exact: true, touch: true, wait: 600 });
    await tap(page, 'Salvar despertar', { touch: true, wait: 1500 });
    check('sono familia: despertar durante o sono', await waitText(page, 'Sono noturno desde') && await has(page, '- 1 despertar'), '');
    await shot(page, 'sp04_sono_em_andamento');
    await tap(page, 'Acordou', { exact: true, touch: true, wait: 1500 });
    check('sono familia: acordou encerra o sono', (await waitText(page, 'Sono registrado até')) && !(await has(page, 'Sono noturno desde')), '');

    await tap(page, dm(d2) + ': ', { contains: true, touch: true });
    await tap(page, '14:00 às 15:10', { contains: true, touch: true, wait: 2000 });
    check('sono familia: registro abre a partir do sono', hash(page).includes('de=sono'), hash(page));
    await tap(page, 'Corrigir', { exact: true, touch: true, wait: 1500 });
    await tapAny(page, [['Remover despertar das 14:30', {}], ['Remover despertar', {}]], { touch: true });
    await fill(page, 'Fim (HH:MM)', '15:30');
    await fill(page, 'Motivo da correção', 'Acordou mais tarde (teste e2e)');
    await tap(page, 'Salvar correção', { touch: true, wait: 1800 });
    check('sono familia: correcao com motivo no historico', await waitText(page, 'Motivo: Acordou mais tarde (teste e2e)'), '');
    await shot(page, 'sp05_correcao_historico');
    await tap(page, 'Voltar', { touch: true, wait: 2000 });
    check('sono familia: voltar retorna ao sono', hash(page).includes('vista=sono') && (await waitText(page, dm(d2) + ': noite 9h40 com 1 despertar - 1 cochilo (1h30) - total 11h10')), hash(page));
    await ctx.close();
  });

  await step('celular: sono profissional so leitura e avaliacao no prontuario', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/pacientes/p1/prontuario?perfil=profissional');
    await tap(page, 'Diário do sono (família)', { touch: true, wait: 2200 });
    const l = await labels(page);
    check('sono profissional: abre do prontuario sem botoes de registro', hash(page).startsWith('#/rotina/p1?vista=sono') && hash(page).includes('de=prontuario') && l.includes('Resumo da semana') && !l.includes('Dormiu agora (noite)') && !l.includes('Registrar sono'), hash(page));
    await shot(page, 'sp06_sono_profissional');
    await tap(page, 'Registrar avaliação do sono no prontuário', { touch: true, wait: 1500 });
    await tap(page, 'Salvar no prontuário', { touch: true, wait: 1000 });
    check('sono profissional: exige avaliacao escrita', await waitText(page, 'Escreva a sua avaliação.'), '');
    await fill(page, 'Sua avaliação', 'Padrão compatível com a rotina relatada (teste e2e).');
    await tap(page, 'Salvar no prontuário', { touch: true, wait: 1000 });
    check('sono profissional: exige revisao dos dados da familia', await waitText(page, 'Confirme que revisou os dados informados pela família.'), '');
    await tap(page, 'Revisei os dados informados pela família', { touch: true, wait: 600 });
    await shot(page, 'sp07_avaliacao_sono');
    await tap(page, 'Salvar no prontuário', { touch: true, wait: 1800 });
    await tap(page, 'Voltar', { touch: true, wait: 2200 });
    check('sono profissional: voltar ao prontuario com a avaliacao', hash(page) === '#/pacientes/p1/prontuario' && (await waitText(page, 'Avaliação do sono')), hash(page));
    await shot(page, 'sp08_prontuario_avaliacao_sono');
    await ctx.close();
  });

  await step('computador: puericultura consulta completa, PDF, calendario e correcao', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/perfil/logomarca?perfil=profissional');
    await sendLogo(page, 'Enviar logomarca', { name: LOGO_A, mimeType: 'image/png', buffer: await makeLogo(page, { text: 'Cl\u00ednica Exemplo A' }) });
    await tap(page, 'Salvar logomarca', { wait: 1500 });

    await nav(page, '#/pacientes/p1/prontuario');
    await tap(page, 'Nova consulta de puericultura', { wait: 2500 });
    const cid = (hash(page).match(/consulta\/(c\d+)/) || [])[1];
    check('puericultura: nova consulta a partir do prontuario', !!cid && (await waitText(page, 'Idade corrigida')), hash(page));
    await tap(page, 'Aplicar modelo', { wait: 1500 });
    await tap(page, 'Puericultura 1 a 2 anos (exemplo)', { wait: 1500 });
    check('puericultura: modelo por faixa etaria aplicado', await waitText(page, 'Modelo usado: Puericultura 1 a 2 anos (exemplo) (v1)'), '');
    await shot(page, 'sp09_puericultura_modelo');
    for (const [f, v] of [['História', 'Sem intercorrências (teste e2e).'], ['Alimentação', 'Refeições da família (teste e2e).'], ['Sono', 'Dorme no berço (teste e2e).'], ['Eliminações', 'Sem alterações (teste e2e).'], ['Vacinação', 'Carteira conferida (teste e2e).']]) await fill(page, f, v);

    await tap(page, 'Incorporar diário do sono', { wait: 1500 });
    check('puericultura: incorporar so apos revisao', (await find(page, 'Incorporar', { exact: true, last: true }))?.disabled === true, '');
    await tap(page, 'Revisei os dados informados pela família', { wait: 600 });
    await tap(page, 'Incorporar', { exact: true, last: true, wait: 1500 });
    check('puericultura: diario do sono incorporado ao campo Sono', await waitText(page, 'Diário do sono incorporado'), '');
    await tap(page, 'Salvar rascunho', { wait: 1500 });

    await tap(page, 'Ver diário do sono', { wait: 2200 });
    check('puericultura: ver diario a partir da consulta', hash(page).includes('vista=sono') && hash(page).includes('consulta=' + cid), hash(page));
    await tap(page, 'Voltar', { wait: 2200 });
    check('puericultura: voltar do diario retorna a consulta', hash(page) === '#/pacientes/p1/consulta/' + cid, hash(page));

    await tap(page, 'Próximo', { wait: 1500 });
    await fill(page, 'Exame físico', 'Bom estado geral (teste e2e).');
    await tap(page, 'Registrar peso, comprimento e PC', { wait: 2500 });
    await fill(page, 'Data da medida *', dmy(new Date()));
    await fill(page, 'Peso', '10,4');
    await fill(page, 'Comprimento', '76,5');
    await fill(page, 'Perímetro cefálico', '45,2');
    await tap(page, 'Salvar medida', { wait: 2500 });
    await tap(page, 'Voltar à consulta', { wait: 2500 });
    check('puericultura: medida da consulta volta ao exame', hash(page).includes('/consulta/' + cid) && hash(page).includes('etapa=avaliacao') && (await waitText(page, 'nesta consulta')), hash(page));
    await shot(page, 'sp10_exame_medidas');
    await fill(page, 'Crescimento', 'Segue a curva (teste e2e).');

    await tap(page, 'Próximo', { wait: 1500 });
    check('puericultura: marcos pela idade corrigida', await waitText(page, 'Faixa: 1 a 2 anos (pela idade corrigida)'), '');
    await tapAny(page, [['Anda sem apoio: Adquirido', { contains: true }], ['Adquirido', { exact: true }]]);
    await tap(page, 'Outro marco', { wait: 1200 });
    await fill(page, 'Marco', 'Empilha dois cubos (teste e2e)');
    await tap(page, 'Incluir marco', { wait: 1200 });
    check('puericultura: outro marco registrado', await waitText(page, 'Empilha dois cubos (teste e2e)'), '');
    await fill(page, 'Desenvolvimento', 'Adequado (teste e2e).');
    await shot(page, 'sp11_marcos');

    await tap(page, 'Próximo', { wait: 1500 });
    await fill(page, 'Avaliação', 'Criança saudável (teste e2e).');
    await fill(page, 'Plano de acompanhamento', 'Manter acompanhamento (teste e2e).');
    await tap(page, 'Dúvida', { exact: true, wait: 1200 });
    await fill(page, 'Dúvida', 'Pode usar travesseiro? (teste e2e)');
    await fill(page, 'Orientação dada', 'Orientado com o texto revisado (teste e2e).');
    await tap(page, 'Salvar dúvida', { wait: 1200 });
    check('puericultura: duvida dos responsaveis com a orientacao dada', (await waitText(page, 'Pode usar travesseiro? (teste e2e)')) && (await has(page, 'Orientação: Orientado com o texto revisado')), '');
    await fill(page, 'Orientações dadas nesta consulta', 'Rotina de sono conversada (teste e2e).');
    await tap(page, 'em 2 meses', { wait: 800 });
    await tap(page, 'Item', { exact: true, wait: 1200 });
    await fill(page, 'O que acompanhar', 'Reavaliar fala (teste e2e)');
    await tap(page, 'Incluir item', { wait: 1200 });
    check('puericultura: item de acompanhamento', await waitText(page, 'Reavaliar fala (teste e2e)'), '');
    await shot(page, 'sp12_conduta');

    await tap(page, 'Próximo', { wait: 1500 });
    check('puericultura: resumo com os marcos', await waitText(page, 'Anda sem apoio (Motor grosso): Adquirido'), '');
    await reveal(page, 'Resumo em PDF');
    check('puericultura: resumo com a proxima consulta sugerida', await waitText(page, 'Próxima consulta: ' + dmy(monthsFrom(2))), dmy(monthsFrom(2)));
    const draft = await downloadPdf(page, 'Resumo em PDF', { keep: 'rascunho' });
    check('puericultura: PDF do rascunho baixado', draft.magic === '%PDF-', draft.name);
    await tap(page, 'Finalizar puericultura', { wait: 1200 });
    await tap(page, 'Finalizar', { exact: true, last: true, wait: 2000 });
    check('puericultura: finalizada fica somente leitura', await waitText(page, 'Puericultura finalizada: somente leitura'), '');
    await shot(page, 'sp13_resumo_finalizado');
    const fin = await downloadPdf(page, 'Resumo em PDF', { keep: 'final' });
    check('puericultura: PDF final com a logomarca da conta', fin.magic === '%PDF-' && fin.image && fin.widths.includes(600), 'larguras ' + fin.widths.join(','));
    await page.waitForTimeout(3000);
    await page.evaluate(() => { window.__printCalled = 0; });
    await tap(page, 'Imprimir', { wait: 2500 });
    const printed = await page.evaluate(() => window.__printCalled || 0);
    const src = await page.evaluate(() => document.getElementById('p360-print-frame')?.src || null);
    const pi = src ? await blobImageInfo(page, src) : null;
    check('puericultura: imprimir com a logomarca', printed > 0 && !!pi && pi.image, 'print ' + printed);

    await nav(page, '#/pacientes/p1/prontuario');
    check('puericultura: consulta no prontuario', await waitText(page, 'Consulta de puericultura (demonstração)'), '');

    await nav(page, '#/pacientes/p1/consulta/' + cid + '?etapa=conduta');
    await tap(page, 'Corrigir', { exact: true, wait: 1500 });
    await fill(page, 'Avaliação', 'Criança saudável; ok (teste e2e).');
    await tap(page, 'Salvar correção', { wait: 1200 });
    check('puericultura: correcao pede motivo', await waitText(page, 'Motivo da correção'), '');
    await fill(page, 'Motivo (fica no histórico)', 'Complemento (teste e2e)');
    await tap(page, 'Salvar correção', { last: true, wait: 1800 });
    await tap(page, 'Etapa 5', { wait: 1500 });
    await reveal(page, 'Versão anterior');
    check('puericultura: historico da correcao com motivo', (await waitText(page, 'Corrigido após finalizar')) && (await has(page, 'motivo: Complemento (teste e2e)')), '');
    await tap(page, 'Versão anterior', { wait: 1200 });
    check('puericultura: versao anterior preservada', (await waitText(page, 'Antes de: Corrigido após finalizar')) && (await has(page, 'Criança saudável (teste e2e).')), '');
    await shot(page, 'sp14_versao_anterior');
    await tap(page, 'Fechar', { wait: 800 });
    for (let i = 0; i < 5; i++) await tap(page, 'Voltar', { exact: true, wait: 1500 });
    check('puericultura: voltar percorre as etapas e sai ao prontuario', hash(page) === '#/pacientes/p1/prontuario', hash(page));

    await open(page, '#/rotina/p1?vista=calendario&modo=dia&dia=' + ymd(monthsFrom(2)) + '&perfil=responsavel');
    check('calendario familia: proxima consulta de puericultura', await waitText(page, 'Próxima consulta de puericultura (data sugerida)'), '');
    await shot(page, 'sp15_calendario_proxima_consulta');
    await nav(page, '#/rotina/p1?vista=calendario&modo=dia&dia=' + ymd(daysFrom(30)));
    check('calendario familia: item de acompanhamento', await waitText(page, 'Acompanhamento: Reavaliar fala (teste e2e)'), '');
    await ctx.close();
  });

  await step('computador: puericultura anterior mantem PDF sem logomarca', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/perfil/logomarca?perfil=profissional');
    await sendLogo(page, 'Enviar logomarca', { name: LOGO_A, mimeType: 'image/png', buffer: await makeLogo(page, { text: 'Cl\u00ednica Exemplo A' }) });
    await tap(page, 'Salvar logomarca', { wait: 1500 });
    await nav(page, '#/pacientes/p1/consulta/c3?etapa=resumo');
    await waitText(page, 'Resumo em PDF', 10000);
    const old = await downloadPdf(page, 'Resumo em PDF');
    check('puericultura: consulta finalizada antes da logomarca sai sem imagem', old.magic === '%PDF-' && !old.image, old.name);
    await ctx.close();
  });

  await step('celular: orientacoes da familia so emitidas', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/rotina/p1/orientacoes?perfil=responsavel');
    const l = await labels(page);
    check('orientacoes familia: so as emitidas', l.includes('Rotina e sono') && !l.includes('Orientação em revisão (teste)'), '');
    await shot(page, 'sp16_orientacoes_familia');
    await tap(page, 'Rotina e sono', { touch: true, wait: 2000 });
    check('orientacoes familia: abre com data de emissao', await waitText(page, 'Emitida em'), '');
    await shot(page, 'sp17_orientacao_aberta');
    const pdf = await downloadPdf(page, 'Baixar PDF', { touch: true, keep: 'orientacao' });
    check('orientacoes familia: PDF baixado', pdf.magic === '%PDF-', pdf.name);
    await tap(page, 'Voltar', { touch: true, wait: 1800 });
    check('orientacoes familia: voltar a lista', hash(page).startsWith('#/rotina/p1/orientacoes'), hash(page));
    await nav(page, '#/rotina/p1/orientacoes/d1');
    check('orientacoes familia: documento interno nao abre', await waitText(page, 'Orientação não encontrada'), '');
    await nav(page, '#/rotina/p2/orientacoes');
    check('orientacoes familia: outra familia nao abre', !(await has(page, 'Rotina e sono')), '');
    await ctx.close();
  });

  await step('computador: permissoes sono e puericultura', async () => {
    for (const perfil of ['recepcao', 'financeiro', 'administrador']) {
      const { ctx, page } = await newPage(browser, DESKTOP);
      await open(page, '#/pacientes/p1/consulta/c3?perfil=' + perfil);
      const a = await waitText(page, 'Acesso restrito');
      await nav(page, '#/rotina/p1?vista=sono');
      const b = await waitText(page, 'Acesso restrito');
      await nav(page, '#/rotina/p1/orientacoes');
      const c = await waitText(page, 'Acesso restrito');
      check('permissoes: ' + perfil + ' nao abre puericultura, sono nem orientacoes', a && b && c, [a, b, c].join('/'));
      if (perfil === 'recepcao') await shot(page, 'sp18_recepcao_acesso_restrito');
      await ctx.close();
    }
    const r = await newPage(browser, DESKTOP);
    await open(r.page, '#/pacientes/p1/consulta/c3?perfil=responsavel');
    check('permissoes: responsavel nao abre a consulta de puericultura', await waitText(r.page, 'Acesso restrito'), '');
    await r.ctx.close();
    const p = await newPage(browser, DESKTOP);
    await open(p.page, '#/rotina/p1/orientacoes?perfil=profissional');
    const pa = await waitText(p.page, 'Acesso restrito');
    await nav(p.page, '#/rotina/p5?vista=sono');
    const pb = await waitText(p.page, 'Rotina não compartilhada');
    check('permissoes: profissional nao usa a area da familia e nao ve rotina nao compartilhada', pa && pb, [pa, pb].join('/'));
    await p.ctx.close();
  });

  // ------------------------------------------------ Anexos da pre-consulta
  function makePdf(title) {
    const stream = 'BT /F1 18 Tf 56 770 Td (' + title + ') Tj ET';
    const objs = [
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Length ' + stream.length + ' >>\nstream\n' + stream + '\nendstream',
    ];
    let out = '%PDF-1.4\n';
    const offs = [];
    objs.forEach((o, i) => { offs.push(Buffer.byteLength(out, 'latin1')); out += (i + 1) + ' 0 obj\n' + o + '\nendobj\n'; });
    const xref = Buffer.byteLength(out, 'latin1');
    out += 'xref\n0 ' + (objs.length + 1) + '\n0000000000 65535 f \n' + offs.map((o) => String(o).padStart(10, '0') + ' 00000 n \n').join('');
    out += 'trailer\n<< /Size ' + (objs.length + 1) + ' /Root 1 0 R >>\nstartxref\n' + xref + '\n%%EOF\n';
    return Buffer.from(out, 'latin1');
  }

  // Textos fora da area visivel saem da arvore de acessibilidade.
  async function seek(page, text, steps = 12) {
    if (await has(page, text)) return true;
    const vh = page.viewportSize().height;
    const vw = page.viewportSize().width;
    for (const dir of [1, -1]) {
      for (let i = 0; i < steps; i++) {
        await page.mouse.move(vw / 2 + (vw > 900 ? 110 : 0), vh / 2);
        await page.mouse.wheel(0, dir * 350);
        await page.waitForTimeout(450);
        if (await has(page, text)) return true;
      }
    }
    return false;
  }

  const PV = 'Pr\u00e9-consulta';
  const ADD_PHOTO = 'Adicionar foto da queixa';
  const ADD_DOC = 'Adicionar exame, laudo ou relat\u00f3rio';
  const REVIEW = 'Conferir anexo antes de incluir';
  const PV_PHOTOS = (n) => 'Fotos da queixa (' + n + ')';
  const PV_DOCS = (n) => 'Exames, laudos e relat\u00f3rios (' + n + ')';
  const REFUSED = 'Arquivo n\u00e3o anexado';
  const PNG_SIG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

  async function refusedFile(page, file, part, touch) {
    await sendLogo(page, ADD_DOC, file, { touch });
    const ok = (await waitText(page, REFUSED)) && (await has(page, part));
    return ok;
  }

  await step('celular: pre-consulta familia anexa, confere, remove e envia', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    const t = { touch: true };
    const next = dmy(addDays(new Date(), 20));
    await open(page, '#/inicio?perfil=responsavel');
    const found = await seek(page, 'Preencher ' + PV.toLowerCase() + ' de ' + next);
    check('pre-consulta: proximas consultas no inicio da familia', found && (await has(page, 'Pr\u00f3ximas consultas')) && (await has(page, PV + ': N\u00e3o preenchida')), '');
    await shot(page, 'pc01_inicio_proximas_consultas');
    await tap(page, 'Preencher ' + PV.toLowerCase() + ' de ' + next, { ...t, wait: 2000 });
    check('pre-consulta: abre a tela da consulta', hash(page) === '#/pre-consulta/a6?de=inicio' && (await waitText(page, 'N\u00e3o preenchida')), hash(page));
    check('pre-consulta: aviso de que anexo nao e diagnostico', await has(page, 'Os anexos ajudam a preparar a consulta. N\u00e3o s\u00e3o diagn\u00f3stico nem resultado validado'), '');
    await fill(page, 'Motivo da consulta', 'Mancha avermelhada na perna (teste)', t);
    await shot(page, 'pc02_formulario');

    const photo = await makeLogo(page, { w: 800, h: 600, text: 'Foto ficticia', color: '#C2570C' });
    await sendLogo(page, ADD_PHOTO, { name: 'mancha-perna.png', mimeType: 'image/png', buffer: photo }, t);
    check('pre-consulta: previa da foto antes de incluir', (await waitText(page, REVIEW)) && (await has(page, 'Pr\u00e9via de mancha-perna.png')) && (await has(page, 'Data da foto (opcional)')), '');
    await shot(page, 'pc03_conferir_foto');
    await fill(page, 'Descri\u00e7\u00e3o (opcional)', 'Mancha na perna (teste)', t);
    await tap(page, 'Incluir anexo', { ...t, wait: 1800 });
    check('pre-consulta: foto incluida como rascunho', (await seek(page, PV_PHOTOS(1))) && (await seek(page, 'Ainda n\u00e3o enviado')), '');
    await shot(page, 'pc04_foto_incluida');

    await sendLogo(page, ADD_DOC, { name: 'laudo-teste.pdf', mimeType: 'application/pdf', buffer: makePdf('Laudo ficticio de teste') }, t);
    check('pre-consulta: PDF conferido antes de incluir', (await waitText(page, REVIEW)) && (await has(page, 'PDF com 1 p\u00e1gina')), '');
    const pdfInfo = await shotPdf(ctx, page, 'Abrir PDF para conferir', 'pc05_pdf_aberto_para_conferir', t);
    check('pre-consulta: PDF abre para conferir', !!pdfInfo && pdfInfo.magic === '%PDF-', pdfInfo ? pdfInfo.magic : 'sem aba');
    await shot(page, 'pc06_conferir_pdf');
    await tap(page, 'Incluir anexo', { ...t, wait: 1200 });
    const noType = await waitText(page, 'Escolha o tipo do documento.');
    await tap(page, 'Laudo', { ...t, exact: true, wait: 900 });
    await tap(page, 'Incluir anexo', { ...t, wait: 1200 });
    const noDate = await waitText(page, 'Informe a data do exame (dd/mm/aaaa).');
    check('pre-consulta: tipo e data do exame obrigatorios', noType && noDate, [noType, noDate].join('/'));
    await fill(page, 'Data do exame', dmy(addDays(new Date(), 3)), t);
    await tap(page, 'Incluir anexo', { ...t, wait: 1200 });
    check('pre-consulta: data futura recusada', await waitText(page, 'A data n\u00e3o pode ser futura.'), '');
    await shot(page, 'pc07_data_futura');
    const examDay = dmy(addDays(new Date(), -7));
    await fill(page, 'Data do exame', examDay, t);
    await tap(page, 'Incluir anexo', { ...t, wait: 1800 });
    check('pre-consulta: laudo incluido com a data do exame', (await seek(page, PV_DOCS(1))) && (await seek(page, 'Laudo - Data do exame: ' + examDay)), '');

    await sendLogo(page, ADD_PHOTO, { name: 'foto-errada.png', mimeType: 'image/png', buffer: await makeLogo(page, { w: 400, h: 300, text: 'Errada' }) }, t);
    await tap(page, 'Incluir anexo', { ...t, wait: 1800 });
    check('pre-consulta: terceiro anexo incluido', await seek(page, PV_PHOTOS(2)), '');
    await shot(page, 'pc08_anexo_por_engano');
    await tap(page, 'Remover foto-errada.png', { ...t, wait: 1200 });
    check('pre-consulta: confirma antes de remover', await waitText(page, 'Remover anexo?'), '');
    await shot(page, 'pc09_confirmar_remocao');
    await tap(page, 'Remover', { ...t, exact: true, last: true, wait: 1800 });
    check('pre-consulta: anexo removido', (await seek(page, PV_PHOTOS(1))) && !(await has(page, 'foto-errada.png')), '');

    const r1 = await refusedFile(page, { name: 'exame.pdf', mimeType: 'application/pdf', buffer: Buffer.from('nao e um PDF de verdade') }, 'embora o nome termine como um deles', true);
    await shot(page, 'pc10_arquivo_recusado');
    await tap(page, 'Entendi', { ...t, wait: 900 });
    const big = Buffer.concat([PNG_SIG, Buffer.alloc(11 * 1024 * 1024)]);
    const r2 = await refusedFile(page, { name: 'foto-enorme.png', mimeType: 'image/png', buffer: big }, 'O limite \u00e9 10 MB por arquivo', true);
    await tap(page, 'Entendi', { ...t, wait: 900 });
    const heic = Buffer.concat([Buffer.from([0, 0, 0, 24]), Buffer.from('ftypheic'), Buffer.alloc(16)]);
    const r3 = await refusedFile(page, { name: 'IMG_0001.HEIC', mimeType: 'image/heic', buffer: heic }, 'formato HEIC', true);
    await tap(page, 'Entendi', { ...t, wait: 900 });
    check('pre-consulta: mensagens claras para formato, tamanho e HEIC', r1 && r2 && r3, [r1, r2, r3].join('/'));

    await tap(page, 'Ver mancha-perna.png', { ...t, wait: 1500 });
    check('pre-consulta: visualizar antes do envio', await waitText(page, 'Arquivo enviado pela fam\u00edlia. N\u00e3o \u00e9 diagn\u00f3stico nem resultado validado.'), '');
    await shot(page, 'pc11_visualizar_foto');
    await tap(page, 'Fechar', { ...t, wait: 900 });

    await tap(page, 'Enviar \u00e0 cl\u00ednica', { ...t, wait: 1200 });
    check('pre-consulta: envio exige autorizacao', await waitText(page, 'Confirme que as informa\u00e7\u00f5es e os anexos'), '');
    await tap(page, 'Autorizo o envio', { ...t, wait: 900 });
    await tap(page, 'Enviar \u00e0 cl\u00ednica', { ...t, wait: 900 });
    check('pre-consulta: enviada com 2 anexos', await waitText(page, PV + ' enviada \u00e0 cl\u00ednica com 2 anexos.'), '');
    await shot(page, 'pc12_enviada');

    await nav(page, '#/pacientes/p1/pre-consulta?perfil=profissional');
    const l = await labels(page);
    check('pre-consulta: profissional ve a consulta e o motivo', l.includes('Consulta de ' + next + ' \u00e0s 09:30') && l.includes('Mancha avermelhada na perna (teste)'), '');
    check('pre-consulta: profissional ve os anexos organizados', (await seek(page, 'Mancha na perna (teste)')) && (await seek(page, 'laudo-teste.pdf')) && !(await has(page, 'Remover')), '');
    await shot(page, 'pc13_profissional_organizado');
    await tap(page, 'Ver laudo-teste.pdf', { ...t, wait: 1500 });
    check('pre-consulta: profissional abre o PDF enviado', await waitText(page, 'Abrir PDF para conferir'), '');
    await shot(page, 'pc14_profissional_ver_pdf');
    await tap(page, 'Fechar', { ...t, wait: 900 });
    await ctx.close();
  });

  await step('computador: pre-consulta na consulta e na agenda do profissional', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/consulta/c1?perfil=profissional');
    check('pre-consulta: cartao na consulta da crianca', (await waitText(page, PV + ' enviada pela fam\u00edlia')) && (await has(page, '1 foto(s) da queixa e 1 exame(s)')), '');
    await shot(page, 'pc15_consulta_com_pre_consulta');
    await tap(page, 'Ver ' + PV.toLowerCase(), { wait: 2000 });
    check('pre-consulta: abre a partir da consulta', hash(page) === '#/pacientes/p1/pre-consulta?consulta=c1', hash(page));
    const l = await labels(page);
    check('pre-consulta: fotos e documentos em grupos', [PV_PHOTOS(1), PV_DOCS(1), 'Mancha no bra\u00e7o (fict\u00edcia)', 'Hemograma (fict\u00edcio)'].every((x) => l.includes(x)), '');
    await shot(page, 'pc16_pre_consulta_organizada');
    await tap(page, 'Ver foto_braco.png', { wait: 1500 });
    check('pre-consulta: foto ampliada para o profissional', await waitText(page, 'Pr\u00e9via de foto_braco.png'), '');
    await shot(page, 'pc17_foto_ampliada');
    await tap(page, 'Fechar', { wait: 900 });
    await tap(page, 'Voltar', { wait: 1800 });
    check('pre-consulta: voltar leva a consulta', hash(page) === '#/pacientes/p1/consulta/c1', hash(page));
    await nav(page, '#/agenda/a1');
    check('pre-consulta: situacao no agendamento', (await waitText(page, PV + ' enviada em')) && (await has(page, 'Ver ' + PV.toLowerCase())), '');
    await ctx.close();
  });

  await step('computador: pre-consulta familia no computador', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pre-consulta/a4?perfil=responsavel');
    check('pre-consulta: computador abre a consulta da Alice', await waitText(page, 'N\u00e3o preenchida'), '');
    await sendLogo(page, ADD_DOC, { name: 'relatorio-teste.pdf', mimeType: 'application/pdf', buffer: makePdf('Relatorio ficticio') });
    await tap(page, 'Relat\u00f3rio m\u00e9dico', { exact: true, wait: 900 });
    await fill(page, 'Data do relat\u00f3rio', dmy(addDays(new Date(), -30)));
    await tap(page, 'Incluir anexo', { wait: 1800 });
    await tap(page, 'Autorizo o envio', { wait: 900 });
    await tap(page, 'Enviar \u00e0 cl\u00ednica', { wait: 900 });
    check('pre-consulta: computador envia relatorio sem texto', await waitText(page, PV + ' enviada \u00e0 cl\u00ednica com 1 anexo.'), '');
    await shot(page, 'pc18_familia_computador');
    await nav(page, '#/pre-consulta/a2');
    check('pre-consulta: crianca de outra familia nao abre', await waitText(page, PV + ' indispon\u00edvel'), '');
    await ctx.close();
  });

  await step('computador: permissoes pre-consulta', async () => {
    const r = await newPage(browser, DESKTOP);
    await open(r.page, '#/agenda/a1?perfil=recepcao');
    const ra = (await waitText(r.page, PV + ' enviada em')) && (await has(r.page, 'Respostas e anexos s\u00f3 o profissional abre.')) && !(await has(r.page, 'Ver ' + PV.toLowerCase()));
    await shot(r.page, 'pc19_recepcao_so_situacao');
    await nav(r.page, '#/pacientes/p1/pre-consulta');
    const rb = await waitText(r.page, 'Acesso restrito');
    check('permissoes: recepcao ve so a situacao, sem anexos', ra && rb, [ra, rb].join('/'));
    await r.ctx.close();
    for (const perfil of ['financeiro', 'administrador']) {
      const { ctx, page } = await newPage(browser, DESKTOP);
      await open(page, '#/pacientes/p1/pre-consulta?perfil=' + perfil);
      const a = await waitText(page, 'Acesso restrito');
      await nav(page, '#/pre-consulta/a1');
      const b = await waitText(page, 'Acesso restrito');
      check('permissoes: ' + perfil + ' nao abre pre-consulta', a && b, [a, b].join('/'));
      await ctx.close();
    }
    const p = await newPage(browser, DESKTOP);
    await open(p.page, '#/pre-consulta/a1?perfil=profissional');
    const pa = await waitText(p.page, 'Acesso restrito');
    await nav(p.page, '#/perfil');
    await tap(p.page, 'Trocar de conta', { wait: 1000 });
    await tap(p.page, 'Dr. Exemplo Colega', { wait: 1500 });
    await nav(p.page, '#/pacientes/p1/pre-consulta');
    const pb = await waitText(p.page, 'Esta conta \u00e9 de outra cl\u00ednica');
    await shot(p.page, 'pc20_outra_clinica');
    await nav(p.page, '#/pacientes/p1/consulta/c1');
    // Sem vinculo com a Luna, a consulta nem abre para o colega.
    const pc = (await waitText(p.page, 'Consulta n\u00e3o encontrada')) && !(await has(p.page, PV + ' enviada pela fam\u00edlia'));
    check('permissoes: profissional nao usa a tela da familia e outra clinica nao ve anexos', pa && pb && pc, [pa, pb, pc].join('/'));
    await p.ctx.close();
  });

  // ---------------------------------------------- Acompanhamento, lembretes e agendamento
  const AG_DRA = 'Dra. Exemplo Demonstra\u00e7\u00e3o';
  const AG_NEXT = 'Pr\u00f3xima semana';
  const AG_REASON = 'Tosse leve h\u00e1 dois dias (teste e2e)';
  const agSlots = (page) => page.evaluate(() => [...document.querySelectorAll('flt-semantics')]
    .filter((e) => e.getAttribute('role') === 'button' || e.hasAttribute('flt-tappable'))
    .map((e) => (e.getAttribute('aria-label') || e.textContent || '').replace(/\s+/g, ' ').trim())
    .filter((t) => /^[a-z\u00e0-\u00fa]{3}, \d{2}\/\d{2} \u00e0s \d{2}:\d{2}$/.test(t)));
  // A conversa fica no rodape; clica direto no botao visivel, sem rolar a tela.
  async function agClick(page, label, opts = {}) {
    const b = await find(page, label, opts);
    if (!b || b.y < 0 || b.y > page.viewportSize().height) return tap(page, label, opts);
    await page.mouse.click(b.x, b.y);
    await page.waitForTimeout(opts.wait || 1400);
  }
  async function agType(page, text) {
    const b = await find(page, 'Mensagem para o assistente', { input: true });
    if (!b) throw new Error('campo da conversa nao encontrado');
    await page.mouse.click(b.x, b.y);
    await page.waitForTimeout(600);
    await page.keyboard.type(text, { delay: 20 });
    await page.keyboard.press('Enter');
    await page.waitForTimeout(1500);
  }
  // Responde tipo, modalidade, profissional e periodo ate aparecerem horarios.
  async function agUntilSlots(page, answers) {
    for (let i = 0; i < 6 && !(await agSlots(page)).length; i++) {
      let hit = false;
      for (const o of answers) {
        if (await find(page, o, { exact: true })) { await agClick(page, o, { exact: true }); hit = true; break; }
      }
      if (!hit) break;
    }
    return agSlots(page);
  }
  const agSee = async (page, text) => (await waitText(page, text, 4000)) || (await seek(page, text));

  await step('computador: fluxo agendar, lembrar, confirmar, reagendar e cancelar', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    // Administracao: troca o lembrete de 2 horas pelo de 7 dias (a consulta nova cai na proxima semana).
    await open(page, '#/lembretes?perfil=administrador');
    await waitText(page, 'Quando enviar');
    await tap(page, '2 horas antes', { wait: 700 });
    await tap(page, '7 dias antes', { wait: 700 });
    await tap(page, 'Salvar intervalos', { wait: 600 });
    check('lembretes: administracao configura os intervalos', await waitText(page, 'Intervalos salvos.'), '7 dias, 2 dias e 1 dia antes');
    await shot(page, 'ag01_admin_intervalos');

    // Responsavel agenda pelo assistente.
    await nav(page, '#/inicio?perfil=responsavel');
    await tap(page, 'Agendar consulta', { wait: 2200 });
    check('agendar: cartao da familia abre o assistente', hash(page).startsWith('#/agendar'), hash(page));
    await waitText(page, 'Para qual crian\u00e7a');
    await agClick(page, 'Luna Exemplo Souza', { exact: true });
    await agType(page, AG_REASON);
    const slots = await agUntilSlots(page, ['Consulta por queixa', 'Presencial', AG_DRA, AG_NEXT]);
    check('agendar: assistente mostra so horarios livres', slots.length > 0, slots.join(' / '));
    await shot(page, 'ag02_assistente_horarios');
    const when1 = slots[0];
    await agClick(page, when1, { exact: true });
    const sum = (await waitText(page, 'Resumo do agendamento')) && (await has(page, 'Quando: ' + when1)) && !!(await find(page, 'Confirmar agendamento', { exact: true }));
    check('agendar: resumo pede confirmacao explicita antes de gravar', sum, when1);
    await shot(page, 'ag03_resumo_confirmacao');
    await agClick(page, 'Confirmar agendamento', { exact: true });
    check('agendar: consulta gravada apos confirmar', (await waitText(page, 'Consulta agendada')) && (await has(page, 'Luna Exemplo Souza - ' + when1)), when1);
    await shot(page, 'ag04_consulta_agendada');
    await agClick(page, 'Preencher pr\u00e9-consulta', { wait: 2200 });
    const m = /pre-consulta\/([^?]+)\?de=agendar/.exec(hash(page));
    const id = m && m[1];
    // O valor do campo so aparece no DOM com o campo em foco.
    const rb = await find(page, 'Motivo da consulta', { input: true });
    if (rb) { await page.mouse.click(rb.x, rb.y); await page.waitForTimeout(700); }
    const reason = await page.evaluate(() => document.activeElement && document.activeElement.value);
    check('agendar: pre-consulta abre com o motivo preenchido', !!id && reason === AG_REASON, hash(page) + ' | ' + reason);
    await shot(page, 'ag05_pre_consulta_apos_agendar');
    await tap(page, 'Voltar', { wait: 1800 });
    check('agendar: voltar da pre-consulta retorna ao assistente', hash(page) === '#/agendar', hash(page));
    if (!id) throw new Error('agendamento sem identificador');

    await nav(page, '#/agenda/' + id + '?perfil=recepcao');
    check('agendar: recepcao ve o horario marcado pela familia', (await agSee(page, 'Luna Exemplo Souza')) && (await agSee(page, 'Agendado pela fam\u00edlia (assistente)')), id);
    await shot(page, 'ag06_recepcao_agendamento_familia');

    // Lembrete: recepcao dispara a rodada, familia confirma.
    await nav(page, '#/lembretes');
    await tap(page, 'Enviar lembretes pendentes agora', { wait: 500 });
    check('lembrar: rodada de envio pela recepcao', await waitText(page, 'Rodada conclu\u00edda'), '');
    const sent = await agSee(page, 'Luna Exemplo Souza - 7 dias antes');
    const masked = await agSee(page, 'Para: Respons\u00e1vel Exemplo A (\u2022\u2022\u2022\u2022 0001) - WhatsApp');
    check('lembrar: registro com destinatario mascarado e status', sent && masked, [sent, masked].join('/'));
    await shot(page, 'ag07_registro_envios');
    const fail = await agSee(page, 'Falha no envio do lembrete');
    const pref = await agSee(page, 'Prefere outro canal de contato');
    check('lembrar: falha e preferencia viram contato manual', fail && pref, [fail, pref].join('/'));

    await nav(page, '#/mensagens?perfil=responsavel');
    const txt = 'Luna tem hor\u00e1rio marcado ' + when1;
    const got = await agSee(page, txt);
    check('lembrar: familia recebe mensagem discreta', got && !(await has(page, 'Tosse')), txt);
    await shot(page, 'ag08_familia_lembrete');
    await tap(page, 'Confirmar', { exact: true, last: true, wait: 1500 });
    check('confirmar: resposta da familia', await waitText(page, 'Presen\u00e7a confirmada. Obrigado!'), '');
    await shot(page, 'ag09_familia_confirmou');
    await nav(page, '#/agenda/' + id + '?perfil=recepcao');
    const c1 = await agSee(page, 'Confirmado pela fam\u00edlia (WhatsApp)');
    const c2 = await agSee(page, 'Resposta: Confirmar');
    check('confirmar: agenda da recepcao atualizada', c1 && c2, [c1, c2].join('/'));
    await nav(page, '#/inicio?perfil=profissional');
    await nav(page, '#/agenda/' + id);
    const p1 = await agSee(page, 'Confirmado pela fam\u00edlia (WhatsApp)');
    const p2 = await agSee(page, 'Lembretes enviados');
    const p3 = !(await find(page, 'Remarcar', { exact: true }));
    check('confirmar: profissional ve confirmacao e lembretes, sem remarcar', p1 && p2 && p3, [p1, p2, p3].join('/'));
    await shot(page, 'ag10_profissional_confirmado');

    // Familia remarca pelo assistente.
    await nav(page, '#/agendar?acao=remarcar&consulta=' + id + '&perfil=responsavel');
    await waitText(page, 'Vamos remarcar a consulta de Luna');
    await agClick(page, AG_NEXT, { exact: true });
    const when2 = (await agSlots(page)).filter((x) => x !== when1)[0];
    if (!when2) throw new Error('sem horario para remarcar');
    await agClick(page, when2, { exact: true });
    await agClick(page, 'Confirmar remarca\u00e7\u00e3o', { exact: true });
    check('reagendar: familia remarca pelo assistente', await waitText(page, 'Consulta remarcada'), when1 + ' -> ' + when2);
    await shot(page, 'ag11_familia_remarcou');
    await nav(page, '#/agenda/' + id + '?perfil=recepcao');
    check('reagendar: agenda registra a remarcacao', await agSee(page, 'Remarcado por fam\u00edlia (assistente): ' + when1 + ' para ' + when2), '');

    // Novo lembrete; familia pede reagendamento pelo botao.
    await nav(page, '#/lembretes');
    await tap(page, 'Enviar lembretes pendentes agora', { wait: 1500 });
    await nav(page, '#/mensagens?perfil=responsavel');
    await agSee(page, 'Luna tem hor\u00e1rio marcado ' + when2);
    await tap(page, 'Reagendar', { exact: true, last: true, wait: 1500 });
    check('reagendar: pedido pelo lembrete registrado', await waitText(page, 'Pedido registrado. Escolha um novo hor\u00e1rio'), '');
    await shot(page, 'ag12_familia_pede_reagendamento');
    await nav(page, '#/lembretes?perfil=recepcao');
    check('reagendar: recepcao recebe pendencia', await agSee(page, 'Pediu reagendamento'), '');
    await shot(page, 'ag13_recepcao_pendencias');
    await nav(page, '#/agenda/' + id);
    check('reagendar: agenda sinaliza o pedido', await agSee(page, 'A fam\u00edlia pediu outro hor\u00e1rio'), '');
    await tap(page, 'Remarcar', { exact: true, wait: 1500 });
    const opts = await agSlots(page);
    await shot(page, 'ag14_recepcao_horarios_livres');
    const when3 = opts[opts.length - 1];
    await tap(page, when3, { exact: true, wait: 1200 });
    await tap(page, 'Confirmar remarca\u00e7\u00e3o', { exact: true, last: true, wait: 600 });
    check('reagendar: recepcao remarca pela agenda', await waitText(page, 'Consulta remarcada para ' + when3), when3);
    check('reagendar: historico da recepcao', await agSee(page, 'Remarcado por recep\u00e7\u00e3o: ' + when2 + ' para ' + when3), '');

    // Cancelamentos: recepcao pela agenda, familia pelo assistente e pelo lembrete fora do prazo.
    await tap(page, 'Cancelar consulta', { exact: true, wait: 1200 });
    await tap(page, 'Cancelar consulta', { exact: true, last: true, wait: 600 });
    check('cancelar: recepcao cancela pela agenda', await waitText(page, 'Consulta cancelada. Hor\u00e1rio liberado.'), id);
    check('cancelar: historico mostra quem cancelou', await agSee(page, 'Cancelado por recep\u00e7\u00e3o'), '');
    await shot(page, 'ag15_recepcao_cancelou');
    await nav(page, '#/inicio?perfil=profissional');
    await nav(page, '#/agenda/' + id);
    check('cancelar: profissional ve o cancelamento', await agSee(page, 'Cancelado por recep\u00e7\u00e3o'), '');

    await nav(page, '#/agendar?acao=cancelar&consulta=a6&perfil=responsavel');
    await waitText(page, 'Confirma o cancelamento');
    await agClick(page, 'Sim, cancelar a consulta', { exact: true });
    check('cancelar: familia cancela pelo assistente dentro do prazo', await waitText(page, 'Consulta cancelada'), 'a6');
    await shot(page, 'ag16_familia_cancelou');
    await nav(page, '#/mensagens');
    // a4 (Alice, hoje 14:30). A familia tambem recebe lembretes das sessoes de psicologia e fisioterapia da Luna.
    await tap(page, 'Cancelar', { exact: true, after: 'Alice tem hor\u00e1rio marcado', wait: 1500 });
    check('cancelar: pedido fora do prazo vai para a recepcao', await waitText(page, 'Como falta pouco para a consulta'), 'a4');
    await nav(page, '#/lembretes?perfil=recepcao');
    const k1 = await agSee(page, 'Cancelou - hor\u00e1rio liberado');
    const k2 = await agSee(page, 'Pediu cancelamento fora do prazo');
    check('cancelar: recepcao recebe os avisos', k1 && k2, [k1, k2].join('/'));
    await ctx.close();
  });

  await step('computador: painel de acompanhamento e criterios', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/acompanhamento?perfil=recepcao');
    const base = (await waitText(page, 'Indicador Frequentes: 2')) && (await has(page, 'Indicador Inativos: 2')) && (await has(page, 'Indicador Retorno pr\u00f3ximo: 3'));
    check('acompanhamento: indicadores iniciais', base, (await labels(page)).match(/Indicador [^|]+/g)?.join(' / ') || '');
    await tap(page, 'Indicador Inativos', { wait: 1500 });
    const protectedNote = await agSee(page, 'mas j\u00e1 t\u00eam consulta marcada e n\u00e3o contam como inativos');
    const list = (await agSee(page, 'Bento Exemplo Alves')) && (await agSee(page, 'Tentativas de contato: 2'));
    check('acompanhamento: lista de inativos com contato e sem quem ja tem consulta', protectedNote && list, [protectedNote, list].join('/'));
    await shot(page, 'ag20_acompanhamento_inativos');
    await tap(page, 'Dr. Exemplo Colega', { wait: 1500 });
    const f1 = (await agSee(page, 'Heitor Exemplo Melo')) && !(await has(page, 'Bento Exemplo Alves'));
    check('acompanhamento: filtro por profissional', f1, '');
    await tap(page, 'Registrar contato com Heitor Exemplo Melo', { wait: 1200 });
    await tap(page, 'Salvar contato', { wait: 600 });
    check('acompanhamento: tentativa de contato registrada', (await waitText(page, 'Tentativa de contato registrada.')) && (await agSee(page, 'Tentativas de contato: 2')), '');
    await shot(page, 'ag21_filtro_profissional_contato');
    await tap(page, 'Todos', { exact: true, wait: 1000 });
    await tap(page, '3 meses', { wait: 1500 });
    const per = (await labels(page)).match(/Indicador [^|]+/g)?.join(' / ') || '';
    check('acompanhamento: filtro por periodo recalcula frequentes (12 meses: 2)', /Indicador Frequentes: \d/.test(per) && !per.includes('Indicador Frequentes: 2'), per);

    // Recepcao agenda por telefone quem estava inativo.
    await nav(page, '#/agendar?acao=agendar');
    await waitText(page, 'Para qual crian\u00e7a');
    await agClick(page, 'Bento Exemplo Alves', { exact: true });
    await agType(page, 'Retorno de acompanhamento (teste e2e)');
    const s = await agUntilSlots(page, ['Retorno', 'Presencial', AG_DRA, AG_NEXT]);
    await agClick(page, s[0], { exact: true });
    await agClick(page, 'Confirmar agendamento', { exact: true });
    const booked = (await waitText(page, 'Consulta agendada')) && !(await find(page, 'Preencher pr\u00e9-consulta'));
    check('agendar: recepcao marca pelo mesmo assistente', booked, s[0] || '');
    await shot(page, 'ag22_recepcao_agendou');
    await nav(page, '#/acompanhamento');
    check('acompanhamento: quem marcou consulta deixa de ser inativo', await waitText(page, 'Indicador Inativos: 1'), '');

    await nav(page, '#/acompanhamento/criterios?perfil=administrador');
    await waitText(page, 'Crit\u00e9rios de acompanhamento');
    for (let i = 0; i < 6; i++) await tap(page, 'Aumentar: Retorno pr\u00f3ximo', { wait: 350 });
    await tap(page, 'Salvar crit\u00e9rios', { wait: 600 });
    check('criterios: administracao altera e salva', await waitText(page, 'Crit\u00e9rios salvos.'), 'retorno proximo 21 dias');
    await shot(page, 'ag23_criterios');
    await nav(page, '#/acompanhamento');
    check('criterios: indicador recalculado', await waitText(page, 'Indicador Retorno pr\u00f3ximo: 4'), (await labels(page)).match(/Indicador [^|]+/g)?.join(' / ') || '');
    await nav(page, '#/acompanhamento/criterios?perfil=recepcao');
    check('criterios: recepcao so consulta', (await waitText(page, 'S\u00f3 a administra\u00e7\u00e3o da cl\u00ednica altera os crit\u00e9rios')) && !(await find(page, 'Salvar crit\u00e9rios')), '');
    await nav(page, '#/acompanhamento?perfil=profissional');
    const own = (await waitText(page, 'Seus pacientes - ' + AG_DRA)) && !(await find(page, 'Registrar contato com'));
    check('acompanhamento: profissional ve so os proprios pacientes', own, '');
    await shot(page, 'ag24_profissional_acompanhamento');
    await ctx.close();
  });

  await step('celular: assistente da familia, urgencia e recepcao', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/inicio?perfil=responsavel');
    check('familia: cartao de consultas na tela inicial', (await agSee(page, 'Mensagens da cl\u00ednica (')) && !!(await find(page, 'Agendar consulta')), '');
    await shot(page, 'ag30_celular_inicio_familia');
    await nav(page, '#/mensagens');
    const pref = (await agSee(page, 'Receber lembretes de consulta')) && (await agSee(page, 'Alice tem hor\u00e1rio marcado'));
    check('familia: preferencia de contato e lembrete no celular', pref, '');
    await shot(page, 'ag31_celular_mensagens');
    await nav(page, '#/agendar?acao=agendar');
    await agClick(page, 'Alice Exemplo Prado', { exact: true });
    await agType(page, 'Ela est\u00e1 com falta de ar e os l\u00e1bios roxos');
    const urg = (await waitText(page, 'Poss\u00edvel urg\u00eancia')) && (await has(page, 'ligue 192')) && !(await agSlots(page)).length;
    check('urgencia: orienta pronto-socorro sem diagnostico nem horarios', urg, '');
    await shot(page, 'ag32_celular_urgencia');
    await tap(page, 'Recome\u00e7ar conversa', { wait: 1500 });
    await agClick(page, 'Falar com a recep\u00e7\u00e3o', { exact: true });
    check('recepcao: assistente encaminha o que nao resolve', await waitText(page, 'Encaminhado \u00e0 recep\u00e7\u00e3o'), '');
    await shot(page, 'ag33_celular_encaminhado');
    await nav(page, '#/lembretes?perfil=recepcao');
    check('recepcao: pendencia do assistente', await agSee(page, 'Encaminhado pelo assistente'), '');
    await ctx.close();
  });

  await step('computador: permissoes acompanhamento, lembretes e agendamento', async () => {
    const rules = [
      ['financeiro', ['#/acompanhamento', '#/lembretes', '#/agendar', '#/mensagens']],
      ['responsavel', ['#/acompanhamento', '#/lembretes']],
      ['profissional', ['#/agendar', '#/mensagens']],
      ['recepcao', ['#/mensagens']],
    ];
    for (const [perfil, routes] of rules) {
      const { ctx, page } = await newPage(browser, DESKTOP);
      await open(page, '#/inicio?perfil=' + perfil);
      const res = [];
      for (const r of routes) {
        await nav(page, r);
        res.push(await waitText(page, 'Acesso restrito', 5000));
      }
      check('permissoes: ' + perfil + ' bloqueado em ' + routes.join(' '), res.every(Boolean), res.join('/'));
      await ctx.close();
    }
  });

  // ---------- Agenda e acompanhamento clinico ----------
  await step('computador: agenda dia, semana, mes, pre-consulta, atendimento, resumo e historico', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/agenda?perfil=profissional');
    check('agenda: dia com horarios livres', await waitText(page, 'Horário livre'), '');
    await shot(page, 'cl01_agenda_dia');
    await tap(page, 'Semana', { exact: true, wait: 1500 });
    check('agenda: semana com contagem de livres', (await waitText(page, 'horário(s) livre(s)')) && hash(page).includes('vista=semana'), hash(page));
    await shot(page, 'cl02_agenda_semana');
    await tap(page, 'Mês', { exact: true, wait: 1500 });
    check('agenda: mes com navegacao', (await waitText(page, 'Próximo mês')) && hash(page).includes('vista=mes'), hash(page));
    await shot(page, 'cl03_agenda_mes');
    await nav(page, '#/agenda/a1');
    check('agenda: horario mostra dados essenciais e pre-consulta', (await waitText(page, 'Dados essenciais')) && (await has(page, 'Responsável:')) && (await has(page, 'Ver pré-consulta')), '');
    await shot(page, 'cl04_horario_dados_essenciais');
    await tap(page, 'Iniciar consulta', { wait: 2500 });
    const cid = (hash(page).match(/consulta\/(c\d+)/) || [])[1];
    check('agenda: iniciar consulta a partir do horario', hash(page).startsWith('#/pacientes/p1/consulta/') && !!cid, hash(page));
    check('agenda: consulta mostra a pre-consulta do horario', await waitText(page, 'Pré-consulta enviada pela família'), '');
    await tap(page, 'Resumo da consulta', { wait: 2000 });
    check('resumo: abre a partir da consulta', hash(page) === '#/pacientes/p1/consulta/' + cid + '/resumo' && (await waitText(page, 'Organizar a consulta com o assistente')), hash(page));
    await fill(page, 'Transcrição ou anotações da consulta (opcional)', 'Pele com lesão eritematosa. Orientei hidratante.');
    await tap(page, 'Organizar rascunho', { wait: 1500 });
    check('resumo: assistente gera rascunho aguardando revisao, sem sugerir avaliacao', (await waitText(page, 'Sugestão para Queixa')) && (await has(page, 'AGUARDANDO REVISÃO')) && (await has(page, 'A avaliação não é sugerida')) && !(await has(page, 'Sugestão para Avaliação')), '');
    check('resumo: aplicar bloqueado antes da revisao', (await isDisabled(page, 'Aplicar ao registro')) === true, '');
    await shot(page, 'cl05_resumo_rascunho_assistente');
    await tap(page, 'Revisei o conteúdo sugerido', { wait: 900 });
    await tap(page, 'Aplicar ao registro', { wait: 1800 });
    check('resumo: aplicado depois da revisao', await waitText(page, 'revisado e aplicado por Dra.'), '');
    await tap(page, 'Continuar consulta', { wait: 2000 });
    await tap(page, 'Próximo', { wait: 1500 });
    await fill(page, 'Avaliação *', 'Avaliação fictícia');
    await tap(page, 'Próximo', { wait: 1500 });
    await tap(page, 'Retorno em 15 dias', { wait: 900 });
    await tap(page, 'Próximo', { wait: 1500 });
    await tap(page, 'Finalizar consulta', { wait: 1500 });
    await tap(page, 'Finalizar', { last: true, wait: 2500 });
    check('resumo: consulta finalizada abre o resumo', hash(page) === '#/pacientes/p1/consulta/' + cid + '/resumo' && (await waitText(page, 'FINALIZADA')), hash(page));
    await shot(page, 'cl06_resumo_finalizado');
    await tap(page, 'Histórico do paciente', { wait: 2000 });
    check('historico: linha do tempo comeca pela consulta (queixa aplicada do rascunho) e pela pre-consulta', hash(page) === '#/pacientes/p1/historico' && (await waitText(page, 'Pré-consulta enviada pela família')) && (await has(page, 'Mancha avermelhada')), hash(page));
    const older = [];
    for (const t of ['Medidas de crescimento', 'Consulta de puericultura']) older.push(!!(await reveal(page, t, { contains: true }).catch(() => null)));
    check('historico: consultas anteriores e crescimento na linha do tempo', older.every(Boolean), older.join('/'));
    await shot(page, 'cl07_historico');
    await nav(page, '#/pacientes/p1/historico/alteracoes');
    const log = await labels(page);
    check('historico: registro de alteracoes com finalizacao, retorno e revisao do rascunho', await waitText(page, 'Consulta finalizada') && log.includes('Retorno recomendado para') && log.includes('Rascunho do assistente revisado e aplicado') && log.includes('Dra. Exemplo Demonstração'), '');
    await shot(page, 'cl07b_registro_alteracoes');
    await nav(page, '#/pacientes/p1/historico');
    await tap(page, 'Comparar consultas', { wait: 2000 });
    check('historico: comparar consultas com crescimento e desenvolvimento', hash(page).startsWith('#/pacientes/p1/historico/comparar') && (await waitText(page, 'Crescimento entre as consultas')) && (await has(page, 'Desenvolvimento ao longo do tempo')), hash(page));
    await shot(page, 'cl08_comparar');
    await nav(page, '#/agenda/a1');
    check('agenda: horario concluido liga ao resumo', (await waitText(page, 'Resumo da consulta')) && (await has(page, 'Concluído')), '');
    await ctx.close();
  });

  await step('computador: diario de atendimentos e tarefas', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/diario?perfil=profissional');
    check('diario: realizadas, pendentes e faltas', (await waitText(page, 'Realizadas:')) && (await has(page, 'Falta (1)')) && (await has(page, 'Registrar falta')), '');
    await shot(page, 'di01_diario');
    await tap(page, 'Falta (1)', { wait: 1200 });
    check('diario: filtro por situacao', !(await has(page, 'Registrar falta')), '');
    await tap(page, 'Todas', { exact: true, wait: 1200 });
    await tap(page, 'Nova tarefa', { wait: 1200 });
    await fill(page, 'Descrição da tarefa', 'Ligar para a família (teste e2e)');
    await tap(page, 'Amanhã', { exact: true, wait: 600 });
    await tap(page, 'Salvar tarefa', { wait: 1500 });
    check('diario: tarefa criada', await waitText(page, 'Ligar para a família (teste e2e)'), '');
    await tap(page, 'Ligar para a família (teste e2e)', { wait: 1500 });
    check('diario: tarefa concluida vai para Concluidas', await waitText(page, 'Concluídas (2)'), '');
    await tap(page, 'Registrar falta', { wait: 1500 });
    // Os filtros com a contagem ficam no topo; com muitas consultas no dia eles saem da tela.
    await page.mouse.move(800, 400); await page.mouse.wheel(0, -5000); await page.waitForTimeout(1200);
    check('diario: registrar falta atualiza a contagem', await waitText(page, 'Falta (2)'), '');
    await shot(page, 'di02_diario_tarefas');
    await ctx.close();
  });

  await step('computador: observacoes internas e visiveis ao responsavel', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/observacoes?perfil=profissional');
    check('observacoes: identifica interna e visivel, sem notas de outra clinica', (await waitText(page, 'Observação interna')) && (await has(page, 'Visível ao responsável')) && (await has(page, 'prefere consultas pela manhã')) && !(await has(page, 'outra clínica')), '');
    await tap(page, 'Nova observação', { wait: 1200 });
    await fill(page, 'Observação', 'Recado de teste para a família (e2e)');
    await tap(page, 'Visível ao responsável', { last: true, wait: 700 });
    await tap(page, 'Salvar observação', { wait: 1500 });
    check('observacoes: nova observacao com data e autor', (await waitText(page, 'Recado de teste para a família (e2e)')) && (await has(page, 'Dra. ')), '');
    await shot(page, 'ob01_observacoes_profissional');
    await nav(page, '#/pacientes/p1/observacoes?perfil=responsavel');
    check('observacoes: responsavel ve so as visiveis', (await waitText(page, 'Recado de teste para a família (e2e)')) && (await has(page, 'caderneta de vacinação')) && !(await has(page, 'prefere consultas pela manhã')) && !(await has(page, 'Nova observação')), '');
    await shot(page, 'ob02_recados_familia');
    await ctx.close();
  });

  await step('celular: agenda da semana e diario', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/agenda?vista=semana&perfil=profissional');
    check('celular: agenda da semana', await waitText(page, 'horário(s) livre(s)'), '');
    await shot(page, 'm_cl01_agenda_semana');
    await nav(page, '#/diario');
    check('celular: diario abre', await waitText(page, 'Realizadas:'), '');
    await shot(page, 'm_di01_diario');
    await ctx.close();
  });

  await step('computador: permissoes agenda, diario, resumo, observacoes e historico', async () => {
    const rules = [
      ['recepcao', ['#/diario', '#/pacientes/p1/historico', '#/pacientes/p1/consulta/c1/resumo', '#/pacientes/p1/observacoes']],
      ['financeiro', ['#/diario', '#/pacientes/p1/observacoes', '#/pacientes/p1/historico/comparar']],
      ['responsavel', ['#/diario', '#/pacientes/p1/historico', '#/pacientes/p1/historico/alteracoes']],
      ['profissional', ['#/agenda/a7']],
    ];
    for (const [perfil, routes] of rules) {
      const { ctx, page } = await newPage(browser, DESKTOP);
      await open(page, '#/inicio?perfil=' + perfil);
      const res = [];
      for (const r of routes) {
        await nav(page, r);
        res.push(await waitText(page, 'Acesso restrito', 5000));
      }
      check('permissoes clinicas: ' + perfil + ' bloqueado em ' + routes.join(' '), res.every(Boolean), res.join('/'));
      await ctx.close();
    }
  });

  // ------------------------------------------------ Etapa 1: familia e profissional
  await step('celular: etapa1 familia saude e documentos liberados', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, '#/pacientes/p1?perfil=responsavel');
    await tap(page, 'Saúde e desenvolvimento', { touch: true, wait: 2000 });
    check('etapa1 familia: abre saude e desenvolvimento', hash(page) === '#/rotina/p1/saude', hash(page));
    const l = await labels(page);
    check('etapa1 familia: proximas consultas com orientacoes antes da consulta', l.includes('Próximas consultas') && l.includes('Antes da consulta'), '');
    await shot(page, 'e1_01_saude_familia');
    check('etapa1 familia: consultas anteriores sem anotacao clinica', (await scrollTo(page, 'Consultas anteriores')) && !(await has(page, 'Avaliação fictícia')), '');
    await shot(page, 'e1_02_saude_consultas');
    await tap(page, 'Documentos da consulta', { touch: true, wait: 2000 });
    check('etapa1 familia: abre documentos da consulta', hash(page).startsWith('#/rotina/p1/documentos'), hash(page));
    const d = await labels(page);
    check('etapa1 familia: receita e orientacao liberadas; atestado nao liberado fica oculto', d.includes('Receituário') && d.includes('Rotina e sono') && !d.includes('Atestado médico'), '');
    await shot(page, 'e1_03_documentos_familia');
    await tap(page, 'Receituário', { touch: true, wait: 2000 });
    check('etapa1 familia: receita abre com data de emissao', await waitText(page, 'Emitido em'), hash(page));
    await shot(page, 'e1_04_receita_familia');
    const pdf = await downloadPdf(page, 'Baixar PDF', { touch: true, keep: 'e1_receita' });
    check('etapa1 familia: PDF da receita baixado', pdf.magic === '%PDF-', pdf.name);
    await tap(page, 'Voltar', { touch: true, wait: 1800 });
    check('etapa1 familia: voltar a lista de documentos', hash(page).startsWith('#/rotina/p1/documentos'), hash(page));
    await nav(page, '#/rotina/p1/documentos/d1');
    check('etapa1 familia: atestado nao liberado nao abre pelo endereco', await waitText(page, 'Documento não encontrado'), '');
    await nav(page, '#/rotina/p2/documentos');
    check('etapa1 familia: crianca de outra familia nao abre', !(await has(page, 'Receituário')), '');
    await ctx.close();
  });

  await step('computador: etapa1 profissional libera e retira documento', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/documentos/d1?perfil=profissional');
    check('etapa1 liberar: atestado emitido comeca oculto para a familia', await scrollTo(page, 'A família ainda não vê este documento'), '');
    await shot(page, 'e1_05_documento_nao_liberado');
    await tap(page, 'Liberar para a família', { wait: 1500 });
    check('etapa1 liberar: pede confirmacao', await waitText(page, 'Liberar para a família?'), '');
    await tap(page, 'Liberar', { exact: true, last: true, wait: 1800 });
    check('etapa1 liberar: documento liberado com historico', (await waitText(page, 'Liberado para a família')) && (await has(page, 'Liberado por')), '');
    await shot(page, 'e1_06_documento_liberado');
    await nav(page, '#/rotina/p1/documentos?perfil=responsavel');
    check('etapa1 liberar: familia passa a ver o atestado', await waitText(page, 'Atestado médico'), '');
    await nav(page, '#/pacientes/p1/documentos/d1?perfil=profissional');
    await tap(page, 'Retirar da área da família', { wait: 1500 });
    await tap(page, 'Retirar', { exact: true, last: true, wait: 1200 });
    check('etapa1 retirar: exige motivo', await waitText(page, 'Informe o motivo da retirada.'), '');
    await fill(page, 'Motivo', 'Liberado por engano (teste e2e)');
    await tap(page, 'Retirar', { exact: true, last: true, wait: 1800 });
    check('etapa1 retirar: motivo no historico', await waitText(page, 'Liberado por engano (teste e2e)'), '');
    await shot(page, 'e1_07_documento_retirado');
    await nav(page, '#/rotina/p1/documentos?perfil=responsavel');
    await page.waitForTimeout(1500);
    check('etapa1 retirar: familia deixa de ver', !(await has(page, 'Atestado médico')), '');
    await ctx.close();
  });

  await step('computador: etapa1 resumo organizado da pre-consulta', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/pre-consulta?perfil=profissional');
    check('etapa1 resumo: resumo organizado com rotulo de assistente', (await scrollTo(page, 'Resumo organizado')) && (await has(page, 'Organizado por regras, sem IA - Revisão humana obrigatória')), '');
    check('etapa1 resumo: respostas originais continuam', await scrollTo(page, 'Respostas originais da família'), '');
    await shot(page, 'e1_08_resumo_pre_consulta');
    await ctx.close();
  });

  await step('computador: etapa1 orientacoes antes da consulta', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/inicio?perfil=profissional');
    await tap(page, 'Orientações antes da consulta', { wait: 2000 });
    check('etapa1 orientacoes: abre a configuracao', hash(page) === '#/orientacoes-previas', hash(page));
    check('etapa1 orientacoes: texto sugerido identificado', await has(page, 'Texto sugerido pelo aplicativo'), '');
    await fill(page, 'Retorno', 'Traga os exames do retorno (teste e2e).');
    await tap(page, 'Revisar e salvar', { wait: 1800 });
    check('etapa1 orientacoes: salvas com revisao', await scrollTo(page, 'Revisado por'), '');
    await shot(page, 'e1_09_orientacoes_config');
    await nav(page, '#/pre-consulta/a6?perfil=responsavel&de=saude');
    check('etapa1 orientacoes: familia ve na pre-consulta', await scrollTo(page, 'Traga os exames do retorno (teste e2e).'), '');
    check('etapa1 orientacoes: aviso de urgencia sempre presente', await has(page, 'procure atendimento de urgência'), '');
    await shot(page, 'e1_10_preconsulta_orientacoes');
    await ctx.close();
  });

  await step('computador: etapa1 hipoteses na consulta', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p5/consulta/c2?etapa=avaliacao&perfil=profissional');
    check('etapa1 hipoteses: campo com aviso de que o assistente nao sugere', await scrollTo(page, 'Escritas por você'), '');
    await fill(page, 'Hipóteses diagnósticas', 'Hipótese fictícia (teste e2e)');
    await tap(page, 'Salvar rascunho', { wait: 1500 });
    check('etapa1 hipoteses: rascunho salvo', await waitText(page, 'Rascunho da consulta salvo'), '');
    await shot(page, 'e1_11_hipoteses');
    await ctx.close();
  });

  await step('computador: etapa1 permissoes area da familia', async () => {
    for (const perfil of ['profissional', 'recepcao', 'financeiro', 'administrador']) {
      const { ctx, page } = await newPage(browser, DESKTOP);
      await open(page, '#/rotina/p1/saude?perfil=' + perfil);
      const a = await waitText(page, 'Acesso restrito');
      await nav(page, '#/rotina/p1/documentos');
      const b = await waitText(page, 'Acesso restrito');
      const res = [a, b];
      if (perfil !== 'profissional') {
        await nav(page, '#/orientacoes-previas');
        res.push(await waitText(page, 'Acesso restrito'));
      }
      check('etapa1 permissoes: ' + perfil + ' bloqueado na area da familia', res.every(Boolean), res.join('/'));
      await ctx.close();
    }
  });

  await step('computador: modelos de documentos biblioteca criar editar', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/modelos?perfil=profissional');
    const l0 = [await waitText(page, 'Modelos de documentos'), await has(page, 'Atestado 1 dia - escola'), await has(page, 'Escola'), !(await has(page, 'Atestado do Dr. Colega'))];
    check('modelos doc: biblioteca com meus modelos em pastas', l0.every(Boolean), l0.join('/'));
    await shot(page, 'dm01_biblioteca');
    await tap(page, 'Da clínica', { wait: 1500 });
    const l1 = [await waitText(page, 'Atestado escolar - padrão da clínica'), await has(page, 'Duplicar para meus modelos')];
    check('modelos doc: modelos da clinica so para usar ou duplicar', l1.every(Boolean), l1.join('/'));
    await shot(page, 'dm02_modelos_clinica');

    await nav(page, '#/modelos/novo?tipo=atestado');
    await waitText(page, 'Novo modelo: Atestado médico');
    await fill(page, 'Nome do modelo *', 'Atestado 2 dias (e2e)');
    await fill(page, 'Pasta', 'Escola');
    await fill(page, 'Dias de afastamento', '2');
    await fill(page, 'Texto do documento', 'Atesto que {{crianca}} foi atendido(a) em {{data_consulta}}. Peso: {{peso}}. [preencher: retorno]');
    check('modelos doc: previa marca campos a conferir', await scrollTo(page, '[conferir: peso]'), '');
    await shot(page, 'dm03_novo_modelo');
    await tap(page, 'Salvar modelo', { wait: 2200 });
    check('modelos doc: modelo criado aparece na lista', await waitText(page, 'Atestado 2 dias (e2e)'), '');

    await nav(page, '#/modelos/mt3/editar');
    await fill(page, 'Nome do modelo *', 'Atestado 1 dia - escola (rev. e2e)');
    await fill(page, 'O que mudou', 'Ajuste de nome no teste e2e');
    await tap(page, 'Salvar modelo', { wait: 2200 });
    await nav(page, '#/modelos/mt3/editar');
    check('modelos doc: editar cria a versao 2 e guarda a 1', (await scrollTo(page, 'v2 · Atestado 1 dia - escola (rev. e2e)')) && (await has(page, 'v1 · Atestado 1 dia - escola')), '');
    await shot(page, 'dm04_versoes_modelo');
    await ctx.close();
  });

  await step('computador: modelos de documentos duas criancas emitir pdf familia', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/pacientes/p1/documentos/novo?tipo=atestado&modelo=mt3&consulta=c1&perfil=profissional');
    const a = [await waitText(page, 'Luna Exemplo Souza'), await has(page, 'Automático (dado confirmado)'), await has(page, 'Gerado de: Modelo')];
    await shot(page, 'dm05_aplicado_luna');
    a.push(await scrollTo(page, '[preencher: orientação para o retorno]', 20));
    check('modelos doc: Luna com dados confirmados e campo variavel marcado', a.every(Boolean), a.join('/'));
    check('modelos doc: atestado sem CID automatico', !(await has(page, 'CID:')), '');
    await shot(page, 'dm05b_previa_luna');
    await fill(page, 'Texto do documento', 'Atesto, para os devidos fins, que Luna Exemplo Souza foi atendida por mim e deve permanecer afastada das atividades escolares por 1 dia. Retorno às atividades no dia seguinte.');
    await tap(page, 'Salvar e revisar', { wait: 1800 });
    await tap(page, 'Revisei o conteúdo');
    await tap(page, 'Marcar como revisado');
    await tap(page, 'Emitir documento', { wait: 1800 });
    const e = [await waitText(page, 'Emitido'), await scrollTo(page, 'Histórico de versões'), await has(page, 'Emitida (finalizada) em')];
    check('modelos doc: emitido com historico de versoes', e.every(Boolean), e.join('/'));
    check('modelos doc: familia nao ve antes de liberar', await scrollTo(page, 'A família ainda não vê este documento'), '');
    await shot(page, 'dm06_emitido_historico');
    const docHash = hash(page);
    await page.waitForTimeout(3000);
    const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 15000 }), tap(page, 'Gerar PDF', { wait: 800 })]);
    const pdf = await pdfFromDownload(dl);
    check('modelos doc: PDF do documento de modelo', pdf.magic === '%PDF-' && pdf.size > 1500, pdf.name + ' ' + pdf.size + ' bytes');
    fs.copyFileSync(await dl.path(), path.join(OUT, 'dm_' + pdf.name));
    await page.waitForTimeout(2500);
    await tap(page, 'Liberar para a família', { wait: 1500 });
    await tap(page, 'Liberar', { exact: true, last: true, wait: 1800 });
    check('modelos doc: liberado para a familia pelo profissional', await waitText(page, 'Liberado para a família'), '');
    await nav(page, '#/rotina/p1/documentos?perfil=responsavel');
    check('modelos doc: familia ve o atestado liberado', await waitText(page, 'Atestado médico'), '');
    await shot(page, 'dm07_familia_documento');

    await nav(page, docHash + '?perfil=profissional');
    await tap(page, 'Criar nova versão', { wait: 2000 });
    await fill(page, 'Dias de afastamento *', '2');
    await tap(page, 'Salvar rascunho', { wait: 1500 });
    check('modelos doc: correcao pede motivo', await waitText(page, 'Criar versão 2'), '');
    await fill(page, 'Motivo da correção *', 'Período corrigido (teste e2e)');
    await tap(page, 'Salvar nova versão', { wait: 1500 });
    await nav(page, docHash);
    const v = [await waitText(page, 'v2 · Rascunho'), await has(page, 'v1 · Emitido'), await scrollTo(page, 'Correção: Período corrigido (teste e2e)')];
    check('modelos doc: nova versao com autor e motivo; emitida preservada', v.every(Boolean), v.join('/'));
    await shot(page, 'dm08_nova_versao');

    await nav(page, '#/pacientes/p3/documentos/novo?tipo=atestado&modelo=mt3');
    const m = [await waitText(page, 'Maya'), !(await has(page, 'Luna Exemplo Souza'))];
    await shot(page, 'dm09_aplicado_maya');
    m.push(await scrollTo(page, '[conferir: data da consulta]', 20));
    m.push(!(await has(page, 'Luna Exemplo Souza')));
    check('modelos doc: Maya sem consulta, campos a conferir e nada da Luna', m.every(Boolean), m.join('/'));
    await shot(page, 'dm09b_previa_maya');
    await ctx.close();
  });

  await step('computador: modelos de documentos permissoes e dados profissionais', async () => {
    for (const perfil of ['recepcao', 'financeiro', 'responsavel']) {
      const { ctx, page } = await newPage(browser, DESKTOP);
      await open(page, '#/modelos?perfil=' + perfil);
      check('modelos doc: ' + perfil + ' sem acesso', await waitText(page, 'Acesso restrito'), '');
      await ctx.close();
    }
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/modelos?perfil=administrador');
    const g = [await waitText(page, 'Modelos da clínica'), await has(page, 'Atestado escolar - padrão da clínica'), !(await has(page, 'Atestado 1 dia - escola')), await has(page, 'Editar')];
    check('modelos doc: gestao edita modelos da clinica e nao ve os pessoais', g.every(Boolean), g.join('/'));
    await shot(page, 'dm10_gestao_clinica');
    await nav(page, '#/perfil/logomarca?perfil=profissional');
    await page.waitForTimeout(1500);
    check('modelos doc: dados profissionais configuraveis', await scrollTo(page, 'Editar dados profissionais'), '');
    await shot(page, 'dm11_dados_profissionais');
    await ctx.close();
  });

  // ---------- Cuidado multidisciplinar (Luna: pediatra, psicologa e fisioterapeuta) ----------
  const RESERVED = 'Anota\u00e7\u00e3o reservada (fict\u00edcia)';
  const CARE = (aba, extra) => '#/cuidado/p1?aba=' + aba + (extra ? '&' + extra : '');
  // Negativo: rola a tela inteira antes de afirmar que o texto nao aparece.
  const absent = async (page, text) => !(await scrollTo(page, text, 10));

  await step('computador: cuidado visao da equipe, areas, comunicacao e documentos', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, CARE('equipe', 'perfil=profissional'));
    const v = [await waitText(page, 'Profissionais envolvidos'), await has(page, 'Plano combinado'), await scrollTo(page, 'Pr\u00f3ximos atendimentos'), await scrollTo(page, 'Evolu\u00e7\u00e3o relevante')];
    check('cuidado: visao compartilhada da equipe', v.every(Boolean), v.join('/'));
    await page.mouse.wheel(0, -5000);
    await page.waitForTimeout(600);
    await shot(page, 'cm01_visao_equipe');
    await tap(page, 'Resumo com IA', { wait: 1500 });
    const ia = [await waitText(page, 'RASCUNHO DA IA (SIMULADO)'), await has(page, 'Revisei e confirmo o texto'), !(await has(page, RESERVED))];
    check('cuidado: IA prepara rascunho identificado, sem reservado', ia.every(Boolean), ia.join('/'));
    await shot(page, 'cm02_ia_rascunho');
    await tap(page, 'Descartar rascunho', { wait: 1200 });

    await nav(page, CARE('psicologia'));
    const ped = [await waitText(page, 'Registros da psicologia'), await scrollTo(page, 'Plano terap\u00eautico'), await absent(page, RESERVED)];
    check('cuidado: pediatra nao ve o reservado da psicologia', ped.every(Boolean), ped.join('/'));
    await page.mouse.wheel(0, -5000);
    await page.waitForTimeout(600);
    await shot(page, 'cm03_psicologia_vista_pela_pediatra');

    await nav(page, CARE('psicologia', 'conta=psi-a'));
    const psi = [await waitText(page, 'Agenda da psicologia'), await scrollTo(page, RESERVED)];
    check('cuidado: psicologa ve o proprio registro reservado', psi.every(Boolean), psi.join('/'));
    await shot(page, 'cm04_psicologia_reservado');

    await nav(page, CARE('fisioterapia', 'conta=fis-a'));
    const fis = [await waitText(page, 'Agenda da fisioterapia'), await has(page, 'Medidas de acompanhamento'), await scrollTo(page, 'Avalia\u00e7\u00e3o funcional')];
    check('cuidado: fisioterapia com agenda, medidas e avaliacao funcional', fis.every(Boolean), fis.join('/'));
    await shot(page, 'cm05_fisioterapia');
    await nav(page, CARE('psicologia'));
    check('cuidado: fisioterapeuta nao ve o reservado da psicologia', await absent(page, RESERVED), '');

    await nav(page, CARE('comunicacao'));
    const com = [await waitText(page, 'Comunica\u00e7\u00e3o da equipe'), await scrollTo(page, 'SOLICITA\u00c7\u00c3O DE PARECER'), await scrollTo(page, 'ENCAMINHAMENTO INTERNO')];
    check('cuidado: comunicacao com encaminhamento e parecer', com.every(Boolean), com.join('/'));
    await page.mouse.wheel(0, -5000);
    await page.waitForTimeout(600);
    await shot(page, 'cm06_comunicacao');

    await nav(page, CARE('documentos', 'conta=psi-a'));
    await waitText(page, 'Documentos da equipe');
    await tap(page, 'Novo documento', { wait: 1500 });
    const doc = [await waitText(page, 'Relat\u00f3rio psicol\u00f3gico'), !(await has(page, 'Receitu\u00e1rio')), !(await has(page, 'Atestado m\u00e9dico'))];
    check('cuidado: psicologa so prepara documentos da propria area', doc.every(Boolean), doc.join('/'));
    await shot(page, 'cm07_documentos_psicologia');
    await ctx.close();
  });

  await step('computador: cuidado perfil profissional, pacientes vinculados e ferramentas medicas', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, '#/profissional?perfil=profissional&conta=psi-a');
    const p = [await waitText(page, 'O que este perfil pode fazer'), await has(page, 'CRP'), await scrollTo(page, 'Pacientes vinculados'), await scrollTo(page, 'Modelos pr\u00f3prios')];
    check('cuidado: perfil da psicologa com registro, pacientes e modelos', p.every(Boolean), p.join('/'));
    await page.mouse.wheel(0, -5000);
    await page.waitForTimeout(600);
    await shot(page, 'cm08_perfil_psicologa');
    await nav(page, '#/pacientes');
    const l = [await waitText(page, 'Luna'), !(await has(page, 'Maya')), !(await has(page, 'Theo'))];
    check('cuidado: psicologa so ve a crianca vinculada', l.every(Boolean), l.join('/'));
    await shot(page, 'cm09_pacientes_vinculados');
    const blocked = [];
    for (const r of ['#/calculadora', '#/pacientes/p1/prontuario', '#/suplementacao']) {
      await nav(page, r);
      blocked.push(await waitText(page, 'Acesso restrito', 5000));
    }
    check('cuidado: psicologa sem calculadora, prontuario medico e suplementacao', blocked.every(Boolean), blocked.join('/'));
    await nav(page, CARE('equipe', 'conta=psi-c'));
    const none = [await waitText(page, 'Acesso restrito'), !(await has(page, RESERVED))];
    check('cuidado: mesma clinica sem vinculo nao abre a ficha', none.every(Boolean), none.join('/'));
    await shot(page, 'cm10_mesma_clinica_sem_vinculo');
    await ctx.close();
  });

  await step('celular: cuidado area da familia e liberacao pela fisioterapeuta', async () => {
    const { ctx, page } = await newPage(browser, MOBILE);
    await open(page, CARE('familia', 'perfil=responsavel'));
    const f = [await waitText(page, 'Pr\u00f3ximas sess\u00f5es'), await scrollTo(page, 'Brincadeira do flamingo'), await scrollTo(page, 'Rotina do sono em 3 passos'), await absent(page, 'Degraus alternados'), await absent(page, RESERVED)];
    check('cuidado: familia ve so o liberado por cada profissional', f.every(Boolean), f.join('/'));
    await page.mouse.wheel(0, -5000);
    await page.waitForTimeout(600);
    await shot(page, 'm_cm11_familia');
    await nav(page, CARE('fisioterapia', 'perfil=profissional&conta=fis-a'));
    await waitText(page, 'Registros da fisioterapia');
    await tap(page, 'Liberar para a fam\u00edlia', { touch: true, wait: 1500 });
    await nav(page, CARE('familia', 'perfil=responsavel'));
    await waitText(page, 'Pr\u00f3ximas sess\u00f5es');
    const r = [await scrollTo(page, 'Degraus alternados'), await absent(page, RESERVED)];
    check('cuidado: exercicio liberado aparece para a familia', r.every(Boolean), r.join('/'));
    await shot(page, 'm_cm12_familia_exercicio_liberado');
    await ctx.close();
  });

  await step('computador: cuidado troca de profissional com autorizacao da familia', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, CARE('equipe', 'perfil=administrador'));
    const g = [await waitText(page, 'Designar profissional'), await absent(page, RESERVED)];
    check('cuidado: gestao organiza a equipe sem ler registros', g.every(Boolean), g.join('/'));
    await page.mouse.wheel(0, -5000);
    await page.waitForTimeout(600);
    await shot(page, 'cm13_gestao_equipe');
    await tap(page, 'Encerrar v\u00ednculo de Psic\u00f3loga Exemplo Ramos', { wait: 1200 });
    await fill(page, 'Motivo do encerramento *', 'Troca de profissional (e2e)');
    await tap(page, 'Encerrar v\u00ednculo', { exact: true, last: true, wait: 1500 });
    await tap(page, 'Designar profissional', { wait: 1200 });
    await tap(page, 'Psic\u00f3logo Exemplo Teixeira', { contains: true, wait: 600 });
    await fill(page, 'Motivo do encaminhamento *', 'Assume a psicologia (e2e)');
    await tap(page, 'Designar', { exact: true, last: true, wait: 1500 });
    check('cuidado: novo psicologo aguarda autorizacao', await scrollTo(page, 'AGUARDANDO AUTORIZA\u00c7\u00c3O DA FAM\u00cdLIA'), '');
    await shot(page, 'cm14_designado_aguardando');
    await nav(page, CARE('psicologia', 'perfil=profissional&conta=psi-c'));
    check('cuidado: sem autorizacao da familia o novo psicologo nao entra', await waitText(page, 'Acesso restrito'), '');
    await nav(page, CARE('familia', 'perfil=responsavel'));
    await waitText(page, 'Autoriza\u00e7\u00f5es pendentes');
    await shot(page, 'cm15_familia_autoriza');
    await tap(page, 'Autorizar acesso', { wait: 1500 });
    await nav(page, CARE('psicologia', 'perfil=profissional&conta=psi-c'));
    const n = [await waitText(page, 'Registros da psicologia'), await scrollTo(page, 'Plano terap\u00eautico'), await absent(page, RESERVED)];
    check('cuidado: novo psicologo ve o plano, nao o reservado da anterior', n.every(Boolean), n.join('/'));
    await shot(page, 'cm16_novo_psicologo');
    await nav(page, CARE('psicologia', 'conta=psi-a'));
    const o = [await waitText(page, 'Seu v\u00ednculo com a crian\u00e7a foi encerrado'), await scrollTo(page, RESERVED), !(await has(page, 'Novo registro'))];
    check('cuidado: psicologa anterior le so os proprios registros', o.every(Boolean), o.join('/'));
    await shot(page, 'cm17_psicologa_anterior');
    await nav(page, CARE('acessos', 'perfil=responsavel'));
    const a = [await waitText(page, 'Registro de acessos e altera\u00e7\u00f5es'), await scrollTo(page, 'encerrou v\u00ednculo (Troca de profissional (e2e))'), await scrollTo(page, 'autorizou v\u00ednculo')];
    check('cuidado: trilha de acessos e alteracoes para a familia', a.every(Boolean), a.join('/'));
    await shot(page, 'cm18_trilha_acessos');
    await ctx.close();
  });

  await step('computador: cuidado troca de clinica', async () => {
    const { ctx, page } = await newPage(browser, DESKTOP);
    await open(page, CARE('familia', 'perfil=responsavel'));
    await tap(page, 'Trocar de cl\u00ednica', { wait: 1200 });
    await tap(page, 'Confirmar troca', { wait: 1500 });
    const t = [await scrollTo(page, 'Autoriza\u00e7\u00f5es pendentes'), await scrollTo(page, 'Brincadeira do flamingo')];
    check('cuidado: troca de clinica encerra a equipe e mantem o liberado', t.every(Boolean), t.join('/'));
    await page.mouse.wheel(0, -5000);
    await page.waitForTimeout(600);
    await tap(page, 'Autorizar acesso', { wait: 1500 });
    await shot(page, 'cm19_troca_de_clinica');
    await nav(page, CARE('equipe', 'perfil=profissional&conta=prof-b'));
    const b = [await waitText(page, 'Profissionais envolvidos'), await absent(page, 'Fisioterapeuta Exemplo Moura'), await absent(page, RESERVED)];
    check('cuidado: nova clinica nao ve a equipe nem os registros anteriores', b.every(Boolean), b.join('/'));
    await page.mouse.wheel(0, -5000);
    await page.waitForTimeout(600);
    await shot(page, 'cm20_nova_clinica');
    await nav(page, CARE('equipe', 'conta=fis-a'));
    check('cuidado: fisioterapeuta da clinica anterior perde a visao da equipe', !(await waitText(page, 'Profissionais envolvidos', 3000)), '');
    await ctx.close();
  });

  await browser.close();
  const failed = report.checks.filter((c) => !c.ok);
  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify(report, null, 2));
  console.log('\nRESUMO: ' + (report.checks.length - failed.length) + '/' + report.checks.length + ' verificacoes aprovadas');
  console.log('Erros de console: ' + [...new Set(report.consoleErrors)].join(' || '));
  console.log('CSP: ' + [...new Set(report.csp)].join(' || '));
  console.log('Erros de pagina: ' + [...new Set(report.pageErrors)].join(' || '));
})();
