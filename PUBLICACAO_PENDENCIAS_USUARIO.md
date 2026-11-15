# Pendências de publicação que dependem da titular

Atualizado em 29/10/2026. Nada aqui foi inventado no código: enquanto cada item
não for fornecido, o build de produção é recusado ou o app avisa que o recurso
não está publicado.

## 1. Dados legais (bloqueiam build de loja)

Preencher `tools/release/publicacao.json` (copiar de `publicacao.example.json`):

| Campo | O que é |
| --- | --- |
| `SUPPORT_EMAIL` | E-mail de suporte que você vai atender |
| `TERMS_URL` | Endereço público dos Termos de Uso revisados por advogado |
| `PRIVACY_URL` | Endereço público da Política de Privacidade (LGPD) |
| `DATA_CONTROLLER_NAME` | Razão social do controlador dos dados |
| `DATA_CONTROLLER_CNPJ` | CNPJ do controlador |
| `DPO_EMAIL` | Contato do encarregado (DPO) |

Sem o arquivo, `tools/release/build_prod.ps1` só gera build com `-Homologacao`
(web ou APK interno), e o app mostra "documento ainda não publicado".

## 2. Google Play

- Conta de desenvolvedor Google Play.
- Chave de upload: criar `upload.jks` fora do repositório e
  `android/key.properties` (ignorado pelo Git):

  ```
  storePassword=...
  keyPassword=...
  keyAlias=upload
  storeFile=C:/caminho/seguro/upload.jks
  ```

  Comando: `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
  (o `keytool` está em `C:\Program Files\Android\Android Studio\jbr\bin`).
- Cadastrar no Firebase o SHA-1/SHA-256 da chave de upload e do Play App
  Signing (necessário para login com Google no Android).
- `android/app/google-services.json` existe só nesta máquina (não vai ao Git);
  em outra máquina, baixar com `firebase apps:sdkconfig ANDROID --project pediatria360-app`.

## 3. Apple / iOS (exige Mac com Xcode)

- Conta Apple Developer, certificado de distribuição e perfil de provisionamento
  para `app.pediatria360` (bundle já alinhado ao app iOS do Firebase).
- Baixar `ios/Runner/GoogleService-Info.plist`
  (`firebase apps:sdkconfig IOS --project pediatria360-app`) e adicioná-lo ao
  alvo Runner no Xcode.
- Login com Google no iOS: adicionar em `Info.plist` o `CFBundleURLTypes` com o
  `REVERSED_CLIENT_ID` desse arquivo. Sem isso o botão Google não funciona no
  iPhone.
- `flutter build ipa --release --dart-define=ENV=prod --dart-define=FORCE_REAL_AUTH=true --dart-define-from-file=tools/release/publicacao.json`

## 4. Firebase de produção

- Decidir se `pediatria360-app` vira produção ou se haverá um projeto separado
  para homologação. Hoje o mesmo projeto recebe os canais de homologação.
- Plano Blaze (Functions). A listagem de Functions do projeto falhou em
  29/10; as Functions das Etapas 1–3 nunca foram publicadas.
- Publicar regras, índices, Storage e Functions **somente com sua
  autorização** (`firebase deploy --only firestore,storage,functions --project <projeto>`).
- App Check: registrar Play Integrity, App Attest/DeviceCheck e reCAPTCHA v3
  (web) no Console; passar a chave do site com `-AppCheckSiteKey`; ligar a
  exigência no Console só depois de conferir as métricas.
- Segredos das Functions (`ANTHROPIC_API_KEY`, WhatsApp, pagamento) via
  `firebase functions:secrets:set`, nunca no repositório.

## 5. Domínio

- Domínio próprio para os documentos legais e, se desejar, para o app web
  (Firebase Hosting → domínio personalizado).

## 6. Validação clínica (bloqueia uso com pacientes)

- Curvas da OMS: os valores LMS são os oficiais (repositório
  `WorldHealthOrganization/anthro`), mas amostrados por mês com interpolação
  entre meses. Um pediatra precisa conferir percentis/escore-Z gerados contra
  as tabelas oficiais em idades de referência.
- Calendário vacinal (`lib/features/vaccines/domain/pni_calendar.dart`): sem
  data de versão. Conferir dose a dose com o calendário vigente do Ministério
  da Saúde e registrar a data da conferência.
- Calculadoras de dose: conferência profissional antes de qualquer uso.

## 7. Fora do escopo desta versão (não anunciar na loja)

Vídeo-consulta, pagamento, assinatura ICP-Brasil, TISS com operadora e
prontuário por voz continuam desligados por flag em `AppConfig` e não aparecem
como disponíveis.
