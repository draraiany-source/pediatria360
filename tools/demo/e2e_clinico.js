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
    const matches = els.filter((e) => (opts.contains ? text(e).includes(label) : text(e).startsWith(label)));
    const el = opts.last ? matches[matches.length - 1] : matches[0];
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2, disabled: el.getAttribute('aria-disabled') === 'true' || el.hasAttribute('disabled'), checked: el.getAttribute('aria-checked') };
  }, { label, opts });
}

async function reveal(page, label, opts = {}) {
  const vh = page.viewportSize().height;
  const vw = page.viewportSize().width;
  for (let i = 0; i < 12; i++) {
    const box = await find(page, label, opts);
    if (box && box.y > 70 && box.y < vh - 90) return box;
    const dy = box ? box.y - vh / 2 : 500;
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
    await nav(page, '#/pacientes/p1/documentos/d1');
    check('versoes: v3 rascunho e anteriores preservadas', (await waitText(page, 'v3 · Rascunho')) && (await has(page, 'v2 · Emitido')), '');
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
    check('consulta: conduta oferece receituario com calculadora e suplementacao', (await has(page, 'Receituário com calculadora')) && (await has(page, 'Consultar suplementação')), '');
    await shot(page, 'd13_consulta_conduta');
    await tap(page, 'Próximo', { wait: 1500 });
    await tap(page, 'Finalizar consulta', { wait: 1500 });
    await tap(page, 'Finalizar', { last: true, wait: 2500 });
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

  await browser.close();
  const failed = report.checks.filter((c) => !c.ok);
  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify(report, null, 2));
  console.log('\nRESUMO: ' + (report.checks.length - failed.length) + '/' + report.checks.length + ' verificacoes aprovadas');
  console.log('Erros de console: ' + [...new Set(report.consoleErrors)].join(' || '));
  console.log('CSP: ' + [...new Set(report.csp)].join(' || '));
  console.log('Erros de pagina: ' + [...new Set(report.pageErrors)].join(' || '));
})();
