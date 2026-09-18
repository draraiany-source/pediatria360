# FASE 0 ? Auditoria inicial Pediatria360

Data: 2026-09-18
Repositorio: pediatria360 (Flutter + Firebase)
Git: main ahead 2 de origin (Suplementacao + Consultorio); redesign Home ainda uncommitted

---

## 1. Arquitetura atual

- Feature-first sob `lib/features/*`
- Camadas parciais: data / domain / presentation (Clean Architecture completa so em auth)
- Estado: Riverpod
- Rotas: GoRouter + Shell (bottom / rail / sidebar)
- Core: theme, services (sync, cache, analytics), widgets, error/Result
- Offline-first: Hive + SQLite + SyncService

## 2. Tecnologias

Flutter >=3.32 | Dart >=3.8 | Riverpod | GoRouter | Firebase (Auth, Firestore, Storage, Functions southamerica-east1, FCM, Analytics, Crashlytics, Remote Config) | Google Sign-In | Dio | pdf/printing | fl_chart | Bunny (video cursos)

## 3. Banco (Firestore)

Colecoes principais: users (+ children/growth/vaccines), appointments, encounters, clinical_documents, visit_summaries, lab_results, voice_sessions, triage_records, development_records, clinic_audit_logs, articles/courses, products/orders, ai_conversations, supplement_*, config, deletion_requests

Storage: users/{uid}/** (privado), public/**

Indices: parcial; faltam indices para supplement_* / algumas queries clinicas

## 4. Autenticacao

- Email/senha + Google
- Roles: parent | professional | admin
- professionalVerified (server) + claim admin
- Sem MFA / biometria
- Guards em route_authorization.dart + Firestore rules

## 5?7. Modulos e telas

### IMPLEMENTADO
Auth, shell/home, criancas, crescimento OMS, vacinas PNI, EMR (encounter/timeline/PDF/assist), biblioteca, IA pais, calculadoras, admin basico, notificacoes FCM, privacidade LGPD (export/delete/consent), gamificacao parcial, redesign Home/sidebar (local)

### PARCIALMENTE IMPLEMENTADO
Consultorio 360 (KPIs stub), telemedicina (agenda OK, video OFF), shop (gateway OFF), suplementacao (UI OK, conteudo clinico pendente), cursos (Bunny), assinatura clinica (hash interno, nao ICP-Brasil), CRM admin basico

### NAO IMPLEMENTADO
Multitenant/clinica, RBAC clinico (recepcao/enfermagem/financeiro), WhatsApp, financeiro completo, PIX/gateway, CRM funil, estoque clinico, relatorios/BI, assinatura ICP-Brasil, MFA, landing comercial SaaS, onboarding clinica, multiunidade, inventario clinico, laudos formalizados, OCR docs

### PRECISA CORRIGIR
- functions/src/voice.ts ausente (exports em index.ts quebram deploy)
- Encoding/acentos em shell/home
- Rotas orfas (/ajustes, /assinatura, sala teleconsulta)
- Assets images faltantes
- Termos/Privacidade URLs placeholder
- Nav Mensagens = notificacoes (nao chat clinico)

## 8. Bugs / riscos

| Risco | Severidade |
|-------|------------|
| Deploy Functions com voice missing | Alta |
| Sem isolamento tenant | Alta (para SaaS multi-clinica) |
| Admin nao acessa area clinica (by design atual) | Media |
| Video/pagamento desligados sem UX uniforme | Media |
| Assinatura != validade juridica ICP | Alta (compliance) |
| DevMode unlock roles so debug | Baixa |

## 9. Seguranca

Pontos fortes: deny-by-default rules, campos server-only, encounters imutaveis apos sign, ownsChild corrigido, secrets Anthropic/Bunny no servidor.

Gaps: sem MFA, sem tenant, API keys Firebase no client (esperado), URLs legais placeholder.

## 10. Duplicacao

Dois lab systems (EMR vs supplement); paths Firestore duplicados; nav primary/sidebar; usecases so em auth; empty states por feature.

## 11?13. Dependencias / API / env

Ver pubspec.yaml. Functions: aiChat, EMR sign/issue docs, clinicalAssist, commerce (joinConsultation stub), bunny, content, gamification, privacy, notifications.

Sem flavors formais; dart-define ENV/EMULATOR; AppConfig feature flags.

## 14?18. Estrutura / aproveitavel / corrigir / criar

Aproveitar: EMR, agenda, auth, rules, sync, growth/vaccines, IA clinical assist, redesign UI, suplementacao estrutura.

Corrigir: voice.ts, encoding, rotas orfas, KPIs clinic, indices, assets.

Criar (roadmap SaaS): Tenant/Clinic/Unit, roles clinicos, financeiro, WhatsApp, CRM, reports, patient portal evolucao, telemedicina video, assinatura legal, landing.

---

## Plano por fases (alinhado ao prompt + realidade do repo)

| Fase | Foco | Aproveita |
|------|------|-----------|
| 0 | Auditoria (ESTE DOC) | ? |
| 1 | Seguranca + modelo Tenant/Clinic + RBAC clinico (extensao roles) | Auth + rules |
| 2 | Pacientes + profissionais + agenda completa | children/EMR/telemedicine |
| 3 | Prontuario unificado + especialidades | EMR + clinic voice |
| 4 | Documentos + Rx + exames | clinical_documents + supplement labs |
| 5 | IA + voz + importacao | clinicalAssist + voice (corrigir CF) |
| 6 | Financeiro | shop orders + novos models |
| 7 | WhatsApp + CRM | notifications + admin |
| 8 | Relatorios + dashboard | clinic dashboard |
| 9 | App paciente | role parent |
| 10 | Telemedicina video | telemedicine flag |
| 11 | Polimento visual | redesign premium |
| 12 | Auditoria final producao | ? |

## Custos ? regra

NAO ativar sem aprovacao: Anthropic prod, WhatsApp Business API, gateway PIX/cartao, Bunny escala, SMS, ICP-Brasil, FCM alem do free tier.

## Aguardando autorizacao

Proxima acao sugerida apos sua aprovacao:
1. Commit do redesign Home (sem custo)
2. Corrigir voice.ts OU remover exports (sem custo)
3. Iniciar FASE 1: desenho Tenant + RBAC (docs + schema) antes de migrar dados
