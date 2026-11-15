# Builds de publicação do Pediatria360.
#
# Sempre ENV=prod e FORCE_REAL_AUTH=true: o modo demonstração (convidado sem
# login) e os emuladores ficam desligados. Nunca passe SKIP_AUTH aqui.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File tools\release\build_prod.ps1 -Target web
#   powershell -ExecutionPolicy Bypass -File tools\release\build_prod.ps1 -Target appbundle
#   powershell -ExecutionPolicy Bypass -File tools\release\build_prod.ps1 -Target apk -AllowDebugSigned
#   (ios/ipa: rodar num Mac com Xcode; mesmos --dart-define)
#
# App Check: acrescente -AppCheckSiteKey <chave reCAPTCHA v3> depois de
# registrar os apps no Console do Firebase.
#
# Dados legais (Termos, Privacidade, suporte, controlador, encarregado) vêm de
# tools/release/publicacao.json (copie publicacao.example.json). Sem eles o
# build de produção é recusado; -Homologacao permite gerar sem (o app avisa
# que os documentos não foram publicados) e NÃO serve para loja.
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('web', 'apk', 'appbundle', 'ipa')]
  [string]$Target,
  [switch]$AllowDebugSigned,
  [switch]$Homologacao,
  [string]$AppCheckSiteKey = ''
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\..')

$defines = @(
  '--dart-define=ENV=prod',
  '--dart-define=FORCE_REAL_AUTH=true'
)

$legalFile = 'tools\release\publicacao.json'
$legalKeys = @('SUPPORT_EMAIL', 'TERMS_URL', 'PRIVACY_URL',
  'DATA_CONTROLLER_NAME', 'DATA_CONTROLLER_CNPJ', 'DPO_EMAIL')
if (Test-Path $legalFile) {
  $legal = Get-Content $legalFile -Raw | ConvertFrom-Json
  $missing = @($legalKeys | Where-Object { -not $legal.$_ })
  if ($missing.Count -gt 0 -and -not $Homologacao) {
    throw "publicacao.json sem: $($missing -join ', ')"
  }
  $defines += "--dart-define-from-file=$legalFile"
} elseif (-not $Homologacao) {
  throw "Falta $legalFile (dados legais). Use -Homologacao só para build interno."
}
if ($Homologacao -and $Target -in @('appbundle', 'ipa')) {
  throw 'AAB/IPA são para loja: preencha publicacao.json e rode sem -Homologacao.'
}
if ($AppCheckSiteKey -ne '') {
  $defines += '--dart-define=ENABLE_APP_CHECK=true'
  $defines += "--dart-define=APP_CHECK_RECAPTCHA_SITE_KEY=$AppCheckSiteKey"
}

if ($Target -ne 'web' -and $Target -ne 'ipa') {
  if (-not (Test-Path 'android\app\google-services.json')) {
    throw 'Falta android/app/google-services.json (firebase apps:sdkconfig ANDROID).'
  }
  if ($AllowDebugSigned) {
    if ($Target -eq 'appbundle') { throw 'AAB para a loja exige android/key.properties.' }
    $env:ALLOW_DEBUG_SIGNED_RELEASE = 'true'
  }
}

$commit = (git rev-parse --short HEAD).Trim()
Write-Host "Build $Target ENV=prod a partir de $commit"
flutter build $Target --release @defines
if ($LASTEXITCODE -ne 0) { throw "flutter build $Target falhou ($LASTEXITCODE)" }

if ($Target -eq 'web') {
  [IO.File]::WriteAllText((Join-Path 'build\web' 'SOURCE_COMMIT.txt'), "$commit`n")
}
