# CHECKLIST_PUBLICACAO_FINAL.md — Pediatria 360

Cada item tem uma forma objetiva de saber se está feito. "Parece pronto"
não conta.

## Compilação (nenhum executado ainda — ver `tool/validate_release.sh`)

- [ ] `flutter doctor -v` sem erro
- [ ] `flutter analyze` — zero erro
- [ ] `flutter test` — 100% dos 223 casos verdes (mais os que forem
      adicionados até o lançamento)
- [ ] `npx tsc --noEmit` nas Functions — limpo
- [ ] `npm test` nas Functions
- [ ] Testes de regra no emulador — 82 casos verdes (69 Firestore + 13 Storage)
- [ ] `flutter build apk --release`
- [ ] `flutter build appbundle --release`
- [ ] `flutter build web --release`
- [ ] `flutter build ios --release --no-codesign` (em macOS)

## Firebase

- [ ] `firebase_options.dart` real, via `flutterfire configure`
      (`DefaultFirebaseOptions.isPlaceholder` deve retornar `false`)
- [ ] `google-services.json` (Android) e `GoogleService-Info.plist` (iOS)
      do projeto real
- [ ] `firestore.rules`/`storage.rules`/índices publicados **antes** de
      qualquer dado real (`firebase deploy --only firestore:rules,firestore:indexes,storage:rules`)
- [ ] Segredos configurados: `ANTHROPIC_API_KEY`, `BUNNY_STREAM_API_KEY`,
      `BUNNY_TOKEN_KEY`
- [ ] App Check configurado
- [ ] Domínio autorizado no Firebase Auth
- [ ] SHA-1/SHA-256 cadastrados (Login Google no Android)

## Conteúdo clínico

- [ ] `assets/data/who_reference.json` substituído pela tabela LMS oficial
      da OMS — enquanto não substituído, o aviso na tela (já implementado)
      precisa continuar visível
- [ ] Calendário PNI conferido contra gov.br
- [ ] Conteúdo de biblioteca com `reviewedBy` preenchido antes de ser
      apresentado como protocolo validado

## Segurança

- [ ] `python3 tool/security_audit.py` sem achado
- [ ] `python3 tool/check_imports.py` sem achado
- [ ] Regras testadas no emulador de verdade, não só lidas
- [ ] Nenhuma chave de API no cliente (`grep -r "sk-ant-" lib/` vazio)
- [ ] Assinatura Android de release configurada (não debug)
- [ ] `key.properties` fora do controle de versão

## LGPD

- [ ] Consentimento obrigatório ligado ao cadastro (já implementado —
      confirmar que aponta para documento real, não placeholder)
- [ ] Termos de Uso e Política de Privacidade publicados em URL real
- [ ] Exportação de dados testada de ponta a ponta
- [ ] Exclusão de conta e cancelamento testados de ponta a ponta
- [ ] Encarregado de dados definido e publicado

## Integrações desativadas — continuam assim até existir contrato

- [ ] `AppConfig.paymentGatewayEnabled = false`
- [ ] `AppConfig.videoConsultationEnabled = false`
- [ ] Nenhum botão simula funcionamento — aviso antes do toque, não erro
      depois

## Lojas

- [ ] Nome definitivo do app
- [ ] Ícone em todas as resoluções
- [ ] Splash screen
- [ ] Screenshots (celular e tablet)
- [ ] Descrição curta e completa
- [ ] Classificação indicativa
- [ ] Data Safety (Play Store) / App Privacy (App Store) preenchidos
      corretamente — refletindo dado de saúde sensível de criança
- [ ] URL de política de privacidade real
- [ ] URL de exclusão de conta (exigida por ambas as lojas)
- [ ] Conta de demonstração para revisão, se solicitada

## Critério de "pronto"

Só marcar este documento como concluído quando **cada checkbox acima**
tiver sido verificado de verdade — não quando parecer razoável que
funcione. Nenhuma linha deste projeto foi compilada até o momento em que
este documento foi escrito; a primeira execução real de
`tool/validate_release.sh` é o que transforma "parece pronto" em "está
pronto".
