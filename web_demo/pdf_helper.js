// Entrega de PDF da demonstracao: baixar ou imprimir, sem bibliotecas
// externas. O PDF e gerado no proprio navegador e nunca sai dele.
(function () {
  'use strict';

  function blobUrl(bytes) {
    return URL.createObjectURL(new Blob([bytes], { type: 'application/pdf' }));
  }

  function isMobile() {
    var ua = navigator.userAgent || '';
    return /Android|iPhone|iPad|iPod/i.test(ua) ||
      (navigator.maxTouchPoints > 1 && /Macintosh/.test(ua));
  }

  function download(bytes, name) {
    var url = blobUrl(bytes);
    var a = document.createElement('a');
    a.href = url;
    a.download = name;
    a.rel = 'noopener';
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    setTimeout(function () { a.remove(); URL.revokeObjectURL(url); }, 60000);
    return 'download';
  }

  function print(bytes, name) {
    var url = blobUrl(bytes);
    // Navegadores de celular nao imprimem PDF dentro de iframe: abre o PDF
    // em outra aba, onde o menu do navegador oferece imprimir/compartilhar.
    if (isMobile()) {
      // Com 'noopener' o window.open sempre devolve null; a aba abre sem ele
      // e o opener e desligado em seguida.
      var w = window.open(url, '_blank');
      if (!w) return download(bytes, name);
      try { w.opener = null; } catch (e) { /* ignora */ }
      return 'tab';
    }
    var old = document.getElementById('p360-print-frame');
    if (old) old.remove();
    var f = document.createElement('iframe');
    f.id = 'p360-print-frame';
    f.title = 'Impressao do documento';
    f.style.cssText = 'position:fixed;right:0;bottom:0;width:1px;height:1px;border:0;opacity:0;';
    f.onload = function () {
      setTimeout(function () {
        try {
          f.contentWindow.focus();
          f.contentWindow.print();
        } catch (e) {
          window.open(url, '_blank', 'noopener');
        }
      }, 400);
    };
    f.src = url;
    document.body.appendChild(f);
    return 'iframe';
  }

  // Visualizar: abre o PDF numa aba nova, com o leitor do navegador.
  function view(bytes, name) {
    var url = blobUrl(bytes);
    var w = window.open(url, '_blank');
    if (!w) {
      URL.revokeObjectURL(url);
      return download(bytes, name);
    }
    try { w.opener = null; } catch (e) { /* ignora */ }
    setTimeout(function () { URL.revokeObjectURL(url); }, 120000);
    return 'tab';
  }

  // Anexo de laudo: abre o seletor do navegador e devolve o arquivo lido
  // na memoria da aba. Nada e enviado para fora do navegador.
  function pick(accept) {
    return new Promise(function (resolve) {
      var input = document.createElement('input');
      input.type = 'file';
      input.accept = accept || '';
      input.style.display = 'none';
      var done = false;
      function finish(v) {
        if (done) return;
        done = true;
        input.remove();
        resolve(v);
      }
      input.addEventListener('cancel', function () { finish(null); });
      input.addEventListener('change', function () {
        var file = input.files && input.files[0];
        if (!file) { finish(null); return; }
        file.arrayBuffer().then(function (buf) {
          finish({ name: file.name, type: file.type || '', bytes: new Uint8Array(buf) });
        }, function () { finish(null); });
      });
      document.body.appendChild(input);
      input.click();
    });
  }

  function openFile(bytes, type) {
    var url = URL.createObjectURL(new Blob([bytes], { type: type || 'application/octet-stream' }));
    var w = window.open(url, '_blank');
    setTimeout(function () { URL.revokeObjectURL(url); }, 120000);
    if (!w) return false;
    try { w.opener = null; } catch (e) { /* ignora */ }
    return true;
  }

  window.p360File = { pick: pick, open: openFile };
  window.p360Pdf = { download: download, print: print, view: view };
})();
