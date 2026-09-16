> **HISTÓRICO — não é o documento atual.**
>
> Lista categorizada da v37 (bloqueador/importante/pós-lançamento/etc.) — conteúdo consolidado em BLOQUEADORES_PRODUCAO.md.
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

# Pediatria 360 v37 — Lista de fechamento técnico

Nenhuma tela nova, nenhum módulo novo, nenhuma funcionalidade alterada
nesta rodada. O que mudou: testes de Storage que não existiam (a regra já
existia, a prova executável não) e um bug real de dupla invocação de
emulador no script de validação.

---

## 1. BLOQUEADORES DE COMPILAÇÃO

Nada novo encontrado nesta rodada além do já registrado em
`ANTES_DE_COMPILAR.md`:

- Nenhuma linha compilada com Flutter real ainda — permanece o maior risco
- `android/`/`ios/` vazios no checkout atual — conferir antes de
  `flutter create` (ver `ANTES_DE_COMPILAR.md`, seção 3)
- Possível ajuste de `intl` na primeira tentativa de `flutter pub get`,
  dependendo da versão exata do Flutter instalado (não é algo que dá para
  prever sem rodar)

## 2. BLOQUEADORES DE PRODUÇÃO

- `firebase_options.dart` de exemplo — projeto Firebase real via
  `flutterfire configure`
- Keystore de release Android (hoje só debug)
- Certificado/provisioning de distribuição iOS
- Termos de Uso e Política de Privacidade — texto ainda não existe, só
  placeholder de URL
- Curvas OMS aproximadas (`who_reference.json`) — aviso já visível na
  tela, mas o dado em si continua não sendo a tabela oficial

## 3. DADOS QUE VOCÊ PRECISA FORNECER

- CNPJ, razão social, endereço
- E-mail de suporte real (hoje `suporte@pediatria360.app`, fictício)
- E-mail e nome do encarregado de dados (LGPD)
- Domínio real (hoje `pediatria360.app`, não existe)
- Projeto Firebase de produção
- Conta Google Play / App Store, dados de faturamento
- Texto final de Termos de Uso e Política de Privacidade — não escrevo
  texto legal sem qualificação para isso

## 4. SERVIÇOS EXTERNOS QUE VOCÊ PRECISA CONTRATAR

- Provedor de videochamada (Daily.co, Twilio, Agora...) — `joinConsultation`
  já valida autorização real, lança `unimplemented` de propósito até
  existir provedor
- Gateway de pagamento (Stripe, Mercado Pago, Pagar.me) — `createOrder`
  funciona, `paymentUrl` retorna `null`
- Certificado ICP-Brasil — para assinatura juridicamente válida de
  receita/atestado (hoje só sela com hash, com aviso disso no PDF e na tela)
- Certificação SBIS/CFM — para prontuário eletrônico com validade plena
- Base oficial/licenciada de CID-10 — hoje só aceita código digitado

## 5. DADOS CLÍNICOS QUE PRECISAM DE VALIDAÇÃO OFICIAL

- Curvas de crescimento OMS — `who_reference.json` é aproximado, aviso
  visível na tela de crescimento, mas o dado em si precisa ser trocado
  pela tabela LMS oficial antes de uso clínico
- Calendário de vacinação PNI — conferir contra
  gov.br/saude/vacinacao/calendario; aviso visível na tela de vacinas
- Conteúdo de biblioteca com `reviewedBy` nulo — não deve ser apresentado
  como protocolo validado até revisão

## 6. FUNCIONALIDADES QUE PODEM FICAR PARA PÓS-LANÇAMENTO

- `awardXp` por leitura de artigo (aula e curso completo já pontuam desde
  a v35 — falta só artigo, que exigiria mudança estrutural na tela de
  detalhe que decidi não apressar)
- Agenda: visão de calendário mensal, bloqueio de horário pontual (férias)
  — hoje só disponibilidade semanal recorrente
- Painel financeiro / gestão de clínica multi-unidade
- Modo hospitalar, equipe multiprofissional com pareceres internos
- Telemonitoramento de pacientes crônicos
- Internacionalização
- Escalas de triagem validadas (TEA, TDAH) — dependem de licença de uso
- Importação de laudo laboratorial (`parseLabText` funciona no servidor,
  sem tela)

---

## O que foi corrigido nesta rodada especificamente

- **Testes de regra de Storage — não existiam.** 50 casos cobriam
  Firestore, zero cobria Storage, mesmo a regra existindo e sendo
  razoavelmente sofisticada (limite de tamanho, tipo de arquivo, dono
  exclusivo). 13 testes novos, cobrindo: envio de imagem dentro do limite,
  rejeição de arquivo que não é imagem, rejeição acima de 8 MB, tentativa
  de escrever na pasta de outro usuário, leitura cruzada entre usuários
  (inclusive profissional tentando ler arquivo de paciente só por ser
  profissional), usuário anônimo, exclusão própria vs. de terceiro,
  caminho público, caminho não declarado. Total: 63 casos de regra.
- **A infraestrutura de teste nem sequer subia o emulador de Storage** —
  `test/rules/package.json` tinha `--only firestore` no script, não
  `firestore,storage`. Corrigido antes de escrever qualquer teste sobre
  uma base que não ia rodar.
- **Bug real de dupla invocação de emulador** em
  `tool/validate_release.sh`: o passo 8 envolvia `npm test` (que já sobe o
  emulador sozinho) dentro de outro `firebase emulators:exec` — tentaria
  religar as portas 8080/9199 duas vezes. Corrigido para o mesmo padrão
  que README.md/SETUP.md já usavam corretamente.
- Contagem de teste de regra corrigida em 7 documentos (50→63).

## O que esta rodada verificou e não achou problema

- Colisão de nome de provider Riverpod: zero, em 92 providers
- Rotas GoRouter: zero `path`/`name` duplicado, em 33 rotas
- Regras de Storage: lógica correta, inclusive a separação entre `write` e
  `delete` (não é redundante — `isImage()` falharia numa exclusão, já que
  não há `request.resource` novo ali)
- `late` fields: inicialização incondicional confirmada nos dois arquivos
  com mais campos desse tipo
