# Gera a DEMONSTRACAO web (lib/main_demo.dart) em build/web.
# Nao usa Firebase nem web/index.html do app real.
#
# Uso:  powershell -ExecutionPolicy Bypass -File tools\demo\build_demo.ps1 [-BaseHref /pediatria360-demo/]

param(
  [string]$BaseHref = '/pediatria360-demo/'
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

flutter build web --release -t lib/main_demo.dart --base-href $BaseHref --no-web-resources-cdn
if ($LASTEXITCODE -ne 0) { throw 'flutter build web falhou' }

$out = Join-Path $root 'build\web'
$html = (Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web_demo\index.html')).Replace('$FLUTTER_BASE_HREF', $BaseHref)
[IO.File]::WriteAllText((Join-Path $out 'index.html'), $html, (New-Object Text.UTF8Encoding $false))
Copy-Item (Join-Path $root 'web_demo\demo_loader.js') $out
Copy-Item (Join-Path $root 'web_demo\pdf_helper.js') $out
Copy-Item (Join-Path $root 'web_demo\README.pages.md') (Join-Path $out 'README.md')
[IO.File]::WriteAllText((Join-Path $out 'SOURCE_COMMIT.txt'), "$(git rev-parse HEAD)`n")
Remove-Item (Join-Path $out 'manifest.json') -ErrorAction SilentlyContinue
[IO.File]::WriteAllText((Join-Path $out '.nojekyll'), '')

# O build nao pode conter configuracao, chave ou endpoint do app real.
# O codigo de registro dos plugins do Firebase entra no JS porque o Flutter Web
# registra todos os plugins do pubspec; sem configuracao, SDK carregado ou
# initializeApp, ele fica inerte. Por isso a lista mira identificadores reais.
$forbidden = @(
  'pediatria360-app', 'AIza', 'firebaseio.com', 'firebaseapp.com', 'appspot.com',
  'identitytoolkit', 'securetoken', 'firestore.googleapis', 'cloudfunctions.net',
  'gstatic.com/firebasejs', 'googleapis.com', 'stripe', 'mercadopago',
  'openai', 'generativelanguage', 'gemini', 'agora', 'twilio'
)
$hits = @()
Get-ChildItem $out -Recurse -File | Where-Object { $_.Extension -in '.js', '.html', '.json', '.mjs' } | ForEach-Object {
  $text = Get-Content -Raw -Encoding UTF8 $_.FullName
  foreach ($term in $forbidden) {
    if ($text -match [regex]::Escape($term)) { $hits += "$($_.Name): $term" }
  }
}
if ($hits.Count -gt 0) {
  $hits | ForEach-Object { Write-Host "PROIBIDO -> $_" -ForegroundColor Red }
  throw 'Build da demonstracao contem referencias ao app real.'
}
Write-Host "Demonstracao pronta em $out (base href $BaseHref). Varredura: nenhum termo proibido." -ForegroundColor Green
