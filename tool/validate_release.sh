#!/usr/bin/env bash
set -e

# Validação real do Pediatria 360 — rode isto na sua máquina, com o Flutter
# instalado. Nada disto roda no ambiente onde o projeto foi desenvolvido:
# não há Flutter/Dart nem acesso à rede ali, por isso nunca rodou até agora.
#
# Ordem importa: cada passo depende do anterior ter dado certo. Pare no
# primeiro erro (o `set -e` acima já faz isso) e me mande a saída completa
# antes de seguir para o próximo — corrigir com base em erro real é o que
# falta fechar.

echo "== 1/9: flutter doctor =="
flutter doctor -v

echo "== 2/9: dependências Flutter =="
flutter clean
flutter pub get

echo "== 3/9: formatação =="
dart format --output=none --set-exit-if-changed lib test

echo "== 4/9: ferramentas próprias do projeto =="
# Verificações que já rodam sem precisar do Flutter — se alguma falhar
# aqui, o analyze abaixo também vai falhar, só que com mensagem pior.
python3 tool/check_syntax.py
python3 tool/check_references.py
python3 tool/check_imports.py
python3 tool/security_audit.py

echo "== 5/9: análise estática real =="
flutter analyze --no-fatal-infos

echo "== 6/9: testes Dart =="
flutter test --reporter expanded

echo "== 7/9: Cloud Functions =="
cd functions
npm ci || npm install
npm run lint
npx tsc --noEmit
npm test
cd ..

echo "== 8/9: regras do Firestore e do Storage =="
# `npm test` já sobe o emulador sozinho (ver test/rules/package.json) —
# envolver de novo aqui em `firebase emulators:exec` religaria a mesma
# porta duas vezes. Mesmo comando que README.md/SETUP.md já documentam.
cd test/rules
npm ci || npm install
npm test
cd ../..

echo "== 9/9: builds =="
# Gera android/ ios/ web/ se ainda não existirem, e aplica os ajustes de
# platform/ com o script já testado (não use cp -r — ver tool/migrate_platforms.py).
if [ ! -d "android" ]; then
  flutter create --platforms=android,ios,web \
    --org app.pediatria360 --project-name pediatria360 .
  python3 tool/migrate_platforms.py
fi

flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
flutter build web --release

# Só em macOS:
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "== iOS (macOS detectado) =="
  flutter build ios --release --no-codesign
fi

echo ""
echo "Tudo passou. Cole a saída completa deste script — não um resumo —"
echo "para eu corrigir com base em erro real, não em suposição."
