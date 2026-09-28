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
    const matches = els.filter((e) => (opts.exact ? text(e) === label : opts.contains ? text(e).includes(label) : text(e).startsWith(label)));
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
    check('consulta: conduta oferece receituario com calculadora e suplementacao', (await has(page, 'Receituário com calculadora')) && (await has(page, 'Suplementação do paciente')), '');
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
    const l2 = await labels(page);
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

  await browser.close();
  const failed = report.checks.filter((c) => !c.ok);
  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify(report, null, 2));
  console.log('\nRESUMO: ' + (report.checks.length - failed.length) + '/' + report.checks.length + ' verificacoes aprovadas');
  console.log('Erros de console: ' + [...new Set(report.consoleErrors)].join(' || '));
  console.log('CSP: ' + [...new Set(report.csp)].join(' || '));
  console.log('Erros de pagina: ' + [...new Set(report.pageErrors)].join(' || '));
})();
