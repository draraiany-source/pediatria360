# FASE 10 — Homologacao (staging Emulator)

## Contas ficticias (apos seed)

Senha de todos: `HomologF10!2026`

| Perfil | Email |
|--------|-------|
| Admin clinica A | admin.a@homolog.pediatria360.test |
| Recepcao A | recepcao.a@homolog.pediatria360.test |
| Medico A | medico.a@homolog.pediatria360.test |
| Financeiro A | financeiro.a@homolog.pediatria360.test |
| Admin clinica B | admin.b@homolog.pediatria360.test |
| Responsavel A | responsavel.a@homolog.pediatria360.test |
| Responsavel B | responsavel.b@homolog.pediatria360.test |

## Como reproduzir

1. Java 21+ no PATH (ex.: Android Studio JBR)
2. Na raiz do app:
   `npx firebase-tools@13 emulators:start --only auth,firestore --project pediatria360-app`
3. Nesta pasta:
   ```
   npm ci
   set FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
   set FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
   npm run seed
   npm run matrix
   ```
4. UI web:
   `flutter run -d chrome --web-port=5180 --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=ENV=staging --dart-define=EMULATOR_HOST=127.0.0.1`
   Repetir com `-d edge` para Edge.

## Evidencia FASE 9 (nao substitui E2E app)

`tools/firestore-rules-tests` — `npm run test:emulator` — 19 pass isolamento entre clinicas.