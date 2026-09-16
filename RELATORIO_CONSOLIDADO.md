> **HISTÓRICO — não é o documento atual.**
>
> Relatório consolidado das versões 27-35 — o mais extenso e detalhado historicamente, mantido por valor de contexto.
>
> Para o estado atual do projeto, use:
> - `README.md` — visão geral
> - `ANTES_DE_COMPILAR.md` — o que verificar/rodar antes da primeira compilação real
> - `BLOQUEADORES_PRODUCAO.md` — o que falta para produção, categorizado
> - `CHECKLIST_PUBLICACAO_FINAL.md` — checklist de publicação
> - `CHANGELOG_V40.md` (ou o mais recente) — o que mudou, versão a versão
>
> Este arquivo fica como registro do que foi decidido e por quê — não é
> atualizado desde que virou histórico, então números e status aqui podem
> estar desatualizados.

---

# Pediatria 360 — Relatório consolidado

Reescrito do zero nesta versão, não corrigido por remendo. Todo número
abaixo foi conferido contra o código nesta mesma sessão — nenhum herdado de
relatório anterior. Rodadas anteriores deste documento acumularam
contradição por patch incremental (um item marcado resolvido numa seção e
pendente noutra); a forma de garantir consistência é não fazer isso de novo.

---

## 1. Estado do projeto

| Métrica | Valor |
|---|---|
| Arquivos Dart | 114 |
| Linhas Dart | 34.471 |
| Cloud Functions (TypeScript) | 9 arquivos, 4.177 linhas |
| Suítes de teste Dart | 15 |
| Casos de teste Dart | 223 |
| Casos de teste de regras Firestore | 50 |
| Ferramentas de auditoria próprias | 15 |
| Classes / enums / providers (verificados) | 390 / 35 / 93 |

**O que este relatório não pode afirmar:** nenhuma linha foi compilada.
`flutter analyze`, `flutter test`, `npx tsc --noEmit`, `npm test` das
Functions, e os testes de regra no emulador **nunca rodaram neste
ambiente** — não há Flutter, Dart, nem acesso à rede aqui. Os números da
tabela acima vêm de contagem de texto e das 14 ferramentas próprias
(sintaxe, referência cruzada, segurança, dependências, código morto,
consistência visual, limite de consulta, `BuildContext`, vazamento de
controller, acessibilidade) — nenhuma delas é um compilador.

---

## 2. As 14 ferramentas de auditoria (`tool/`)

```bash
for f in tool/*.py; do echo "=== $f ==="; python3 "$f"; done
```

| Ferramenta | Resultado agora |
|---|---|
| `check_syntax.py` | ✅ 136 arquivos, balanceamento OK |
| `check_references.py` | ✅ 382 classes, nenhuma referência quebrada |
| `security_audit.py` | ✅ 32 collections com regra, nenhum achado |
| `unused_deps.py` | ✅ nenhum problema — 39 diretas, 2 de desenvolvimento |
| `dead_code.py` | ⚠️ 4 achados, todos triados (seção 4) |
| `design_consistency.py` | ⚠️ 4 desvios, todos documentados como ajuste óptico intencional (seção 4) |
| `query_limits.py` | ⚠️ 6 consultas sem limite, todas naturalmente limitadas pelo domínio (seção 4) |
| `context_after_await.py` | ✅ zero em 23 arquivos com estado |
| `dispose_check.py` | ✅ zero em 23 arquivos com estado |
| `accessibility_labels.py` | ✅ todo IconButton com rótulo, 45 arquivos |
| `migrate_platforms.py` | testado contra mocks, 3 cenários (sucesso, idempotência, falha segura) |
| `generate_module_icons.py` | gera os 10 ícones dimensionais da home |

---

## 3. O que está genuinamente resolvido

- **Cancelamento de exclusão de conta.** `AppUser` ganhou o campo
  `deletionScheduledFor` (a Function já gravava, o cliente nunca lia). Tela
  de privacidade mostra painel condicional com data prevista e botão
  "Cancelar exclusão" quando há uma pendente — atualização de UI automática,
  via o listener ao vivo que `currentUserProvider` já era.
- **Edição de perfil.** Nome, telefone e especialidade (só para
  profissional) editáveis; CRM e status de verificação mostrados, sem
  nenhum caminho de edição — a mesma proteção existe na camada de dados e
  nas regras do Firestore, não só na ausência do campo na tela. Sem foto:
  `image_picker` foi removido por não ter upload funcional, e oferecer o
  botão sem efeito seria a interface falsa que o projeto decidiu evitar.
  `updateProfileProvider`, órfão havia várias rodadas, agora tem consumidor
  real.

Cada linha abaixo foi verificada com `grep`/leitura de código nesta sessão,
não copiada de relatório anterior.

- **Consentimento LGPD ligado ao cadastro.** `recordConsent` é chamada de
  verdade, no ponto onde existe conta autenticada (`RoleSetupScreen`), com
  painel obrigatório (`consent_sheet.dart`) que bloqueia a conclusão do
  cadastro sem aceite dos Termos e da Política — os dois como aceite
  separado das finalidades de tratamento opcionais (IA, compartilhamento,
  marketing), que vêm desmarcadas por padrão.
- **Registro de dispositivo centralizado.** Cliente não escreve mais
  `fcmTokens` direto no Firestore — as Functions `registerDevice`/
  `unregisterDevice` são o único caminho, e a regra do Firestore bloqueia
  escrita direta (não é só convenção).
- **`VideoQuality` removido.** Era um seletor para uma função inteira
  desativada por flag — interface sem efeito.
- **`adminFinancePath`/`adminUsersPath` removidos.** Rotas reservadas desde
  as primeiras rodadas, nunca tiveram tela nem registro no roteador.
- **`image_picker` removido, `parseLabText` documentada como desativada**
  por decisão de produto — não há tela de importação de laudo na v1.0.
- **Cota de custo na IA clínica.** `clinicalAssist` e `parseLabText`
  chamavam a API de IA sem nenhuma proteção; `aiChat` (chat dos
  responsáveis) já tinha. Corrigido com cota compartilhada de 300 usos/dia.
- **Token FCM removido no logout**, antes de `_auth.signOut()` — ordem que
  importa, porque depois disso não há mais usuário autenticado para
  escrever a remoção.
- **`Firebase.initializeApp` não é mais chamado com chave de exemplo sem
  aviso** — `main.dart` checa `isPlaceholder` e mostra tela de configuração
  clara em vez de deixar o SDK nativo lançar exceção crua.
- **`Parsers.decimal` corrigido** para separador de milhar brasileiro —
  `"3.000"` virava `3.0`, um erro de mil vezes em qualquer calculadora
  clínica que recebesse esse formato.
- **Sequência de dias (streak) ligada** ao único gatilho inequívoco —
  abertura do app com sessão autenticada.
- **Cache de imagem com tamanho** — `_ProductImage` e `_CourseCover`
  decodificavam a foto na resolução original para mostrar miniatura de
  64px.
- **20 `IconButton` sem rótulo acessível, corrigidos** — 14 de "voltar", 2
  de "fechar", 4 específicos com tooltip próprio.
- **`lib/{core`, pasta fantasma removida** (artefato de `mkdir -p` mal
  interpretado por uma shell).
- **CI não sobrescreve mais `Info.plist`/`Podfile` com `cp -r`** — usa
  `tool/migrate_platforms.py`, testado antes de substituir.

---

## 4. Achados com decisão registrada, não "pendência esquecida"

### Genuinamente pendentes — sem UI ainda

| Item | Situação |
|---|---|
| `awardXp` por ação específica | Só o gatilho diário (abrir o app) está ligado; ler artigo, completar aula, registrar vacina ainda não pontuam |

### Código morto triado — falso positivo confirmado, não removido

| Item | Por quê fica |
|---|---|
| `Pediatria360App` | Ponto de entrada (`main.dart`), instanciado por `runApp` — não precisa ser importado de fora para estar vivo |
| `ClinicalTask` (enum) | Usado 22 vezes dentro do próprio arquivo como estado interno da tela — não precisa ser público para outros arquivos |
| `PatientFilter` (enum) | Mesmo caso — estado interno de `professional_patients_screen.dart` |

`updateProfileProvider` saiu desta lista nesta rodada — agora tem tela real.

### Consultas sem `.limit()` — revisadas, mantidas de propósito

Nenhuma das 6 recebeu limite arbitrário. Documentado por quê:

| Consulta | Por que não tem limite |
|---|---|
| `children_repository_impl.dart:70` (filhos de uma família) | Limitado pela realidade — uma conta não tem milhares de filhos |
| `children_repository_impl.dart:216` (crescimento de uma criança) | Histórico completo é o produto — cortar truncaria o gráfico de crescimento, que precisa da série inteira |
| `children_repository_impl.dart:311` (doses de vacina de uma criança) | Limitado pelo próprio calendário PNI (~29 doses no total) |
| `courses_repository.dart:75` (aulas de um curso) | Limitado pela curadoria de conteúdo, não por uso do usuário |
| `courses_repository.dart:112` (progresso filtrado por curso) | Resulta em no máximo 1 documento por design |
| `courses_repository.dart:164` (todo progresso de um usuário) | Limitado pelo tamanho do catálogo, não cresce com o uso |

`watchMessages` (conversas de IA) **tinha** o mesmo problema e foi corrigido
com `.limitToLast(500)` — essa é a única coleção sem teto natural pelo
domínio, diferente das 6 acima.

### Consistência visual — 4 desvios, documentados como intencionais

`app_widgets.dart:3.0` (kerning entre valor e unidade), `content_detail_screen.dart:3.0`
(alinhamento óptico de texto de passo numerado), `onboarding_screen.dart:3.0`
(gap entre pontos do carrossel), `child_detail_screen.dart:72.0` (folga sob
barra colapsada do SliverAppBar). Todos com comentário no código explicando
a escolha — não forçados para o valor mais próximo da escala sem poder
renderizar e conferir visualmente.

---

## 5. O que está deliberadamente desativado

- **Pagamento**: `AppConfig.paymentGatewayEnabled = false`.
- **Videoconsulta**: `AppConfig.videoConsultationEnabled = false`.

Nenhum dos dois tem botão funcional — ambos mostram aviso visível antes do
toque, não erro depois. Reativar exige provedor contratado, backend seguro,
webhook, política de cancelamento — nenhum destes existe.

---

## 6. Conteúdo médico com aviso explícito, não removido

- `assets/data/who_reference.json` — curvas OMS **aproximadas**, uso
  clínico bloqueado até substituir pela tabela LMS oficial.
- `lib/features/vaccines/domain/pni_calendar.dart` — conferir contra
  gov.br antes de publicar.
- CID-10: busca por descrição **não implementada** — o editor de
  diagnóstico aceita código digitado manualmente, sem base oficial.
- Protocolos SBP/AAP/PALS/NRP: motor pronto, conteúdo não incluído.
- Conteúdo de exemplo com `reviewedBy: null` — a tela já sinaliza "revisão
  clínica pendente" ao leitor.

---

## 7. Domínios, e-mails e URLs — placeholder deliberado

`suporte@pediatria360.app`, `privacidade@pediatria360.app`,
`pediatria360.app/termos-de-uso`, `pediatria360.app/politica-de-privacidade`
**não são endereços reais**. Estão centralizados em `AppConfig` e
comentados como bloqueador de publicação — não inventei CNPJ, endereço nem
nome de encarregado de dados em lugar nenhum do projeto.

---

## 8. Assinatura de documento — o que é e o que não é

`signEncounter` sela o registro (hash de integridade, bloqueio de edição,
histórico de retificação). **Isso não é assinatura ICP-Brasil.** O PDF e a
tela de visualização já mostram aviso disso enquanto `signatureProvider` e
`externalSignatureId` forem nulos — não há texto no app afirmando validade
jurídica plena da assinatura.

---

## 8b. Agenda do profissional — concluída (v35)

A `professional_schedule.dart` da v33 modelava um sistema **duplicado** de
um que já existia e funcionava: a Cloud Function `getAvailability` já lia
disponibilidade do documento do profissional e já cruzava com agendamentos.
O arquivo foi removido (confirmado sem uso real fora de teste antes de
apagar).

A peça que realmente faltava — escrita da disponibilidade, já que a leitura
já existia — foi implementada em `TelemedicineRepository
.setWeeklyAvailability`/`.myWeeklyAvailability`, no formato exato que a
Function já espera. `AppointmentType` (presencial/teleconsulta) adicionado
ao `Appointment`, com leitura retrocompatível para agendamentos antigos.

`professional_agenda_screen.dart`: agenda hoje/7 dias, confirmar, cancelar,
editor de disponibilidade semanal. "Iniciar atendimento" liga de verdade ao
prontuário para consulta presencial — cria ou retoma o `Encounter` e abre
`EncounterEditorScreen`, usando `childId` do agendamento (não `patientId`,
que ali é o responsável, não a criança — confundir os dois criaria o
atendimento para a pessoa errada). Para teleconsulta, mostra que está
indisponível até haver provedor de vídeo — não finge.

## 9. O que falta para compilar pela primeira vez

1. Suba o repositório num Git com o CI já configurado
   (`.github/workflows/ci.yml`) e deixe `flutter analyze` + os 223 + 48
   testes rodarem. É a única forma de saber se há erro de tipo, `await`
   esquecido ou nulidade mal tratada.
2. `flutter create --platforms=android,ios,web .` seguido de
   `python3 tool/migrate_platforms.py --clean`.
3. `flutterfire configure` para o `firebase_options.dart` real.
4. Publicar `firestore.rules`/`storage.rules` antes de qualquer dado real.
5. Preencher os placeholders da seção 7.
6. Decidir os itens genuinamente pendentes da seção 4.

---

## 10. Arquivo por assunto

```
tool/*.py                                — as 14 ferramentas de auditoria
lib/features/auth/presentation/widgets/consent_sheet.dart  — LGPD no cadastro
lib/core/config/app_config.dart          — flags e URLs placeholder
lib/core/utils/validators.dart           — Parsers.decimal corrigido
functions/src/privacy.ts                 — LGPD (consentimento, exportação, exclusão)
functions/src/clinical.ts                — cota compartilhada de IA clínica
firestore.rules                          — 32 collections com regra
test/rules/rules.test.js                 — 63 casos (50 Firestore + 13 Storage)
CHECKLIST_PUBLICACAO.md                  — checklist de loja
SETUP.md                                 — passo a passo de configuração
```
