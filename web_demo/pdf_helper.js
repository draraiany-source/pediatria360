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

  window.p360Pdf = { download: download, print: print };
})();
