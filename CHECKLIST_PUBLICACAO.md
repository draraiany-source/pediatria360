> **HISTÓRICO — não é o documento atual.**
>
> Checklist de publicação inicial — substituído por CHECKLIST_PUBLICACAO_FINAL.md.
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

# Checklist de publicação — Pediatria 360 v1.0

Roteiro do que precisa estar feito antes de submeter às lojas. Cada item tem
como conferir.

Itens marcados **⛔ bloqueia** impedem o lançamento. Os demais são
recomendações fortes.

---

## 1. Verificação automática

Tudo abaixo roda no CI a cada push, mas confirme localmente antes de gerar o
build de release:

```bash
python3 tool/check_syntax.py       # balanceamento de delimitadores
python3 tool/check_references.py   # símbolos inexistentes
python3 tool/security_audit.py     # 10 verificações de segurança
python3 tool/unused_deps.py        # dependências declaradas x usadas
python3 tool/dead_code.py          # código sem uso (informativo)

flutter analyze                    # ⛔ bloqueia se acusar erro
flutter test                       # ⛔ 223 casos precisam passar
cd test/rules && npm test          # ⛔ 63 casos de segurança
cd functions && npx tsc --noEmit   # ⛔ tipagem das Functions
```

> **Nada disso foi executado durante o desenvolvimento.** O ambiente não tinha
> SDK do Flutter nem acesso à rede. As ferramentas próprias cobrem símbolo
> inexistente e sintaxe; **não cobrem tipo errado, `await` esquecido nem
> nulidade**. A primeira execução do `flutter analyze` vai acusar coisas.

---

## 2. Dados clínicos ⛔ bloqueia

Estes três não são código — são conteúdo que precisa vir de fonte oficial.
Publicar sem eles significa entregar números plausíveis e errados.

| Item | Onde | O que fazer |
|---|---|---|
| **Curvas da OMS** | `assets/data/who_reference.json` | Substituir pelas tabelas LMS oficiais de [who.int](https://www.who.int/tools/child-growth-standards/standards). O formato já é o mesmo; nenhuma linha de Dart muda. A matemática está testada — os números não são os reais. |
| **Calendário do PNI** | `lib/features/vaccines/domain/pni_calendar.dart` | Conferir contra [gov.br/saude/vacinacao/calendario](https://www.gov.br/saude/pt-br/vacinacao/calendario). O esquema muda: a VOP virou VIP em 2023. |
| **Tabela CID-10** | não existe | O editor de diagnóstico aceita código digitado. Para busca por descrição, carregar a tabela oficial do Ministério da Saúde. |

**Conteúdo da biblioteca:** os 3 artigos do `tool/seed/seed.js` são exemplos de
estrutura, com `reviewedBy: null`. A tela sinaliza "revisão clínica pendente"
ao leitor. Substituir por conteúdo revisado por pediatra e preencher o campo.

---

## 3. Conformidade regulatória ⛔ bloqueia

### Prontuário eletrônico

Sistema de registro clínico no Brasil exige certificação **SBIS/CFM**
(NGS1 ou NGS2). O que está construído — selo de integridade, hash, histórico
imutável, retificação vinculada — atende requisitos técnicos, mas a
certificação é processo formal junto à SBIS.

### Assinatura de receita e atestado

`signEncounter` **sela** o registro: congela, calcula hash, impede edição.
Isso não é assinatura **ICP-Brasil**, exigida pelo CFM para validade jurídica
plena.

Os campos `signatureProvider` e `externalSignatureId` estão prontos para
receber o retorno do provedor credenciado. **Enquanto forem nulos**, o PDF
imprime o aviso correspondente e a tela informa o médico. Verifique que esse
aviso está visível antes de publicar.

### Telemedicina

Segue a Resolução CFM 2.314/2022. A sala de vídeo **não está integrada** —
`joinConsultation` valida permissão e janela de horário e então lança
`unimplemented`. Escolher provedor envolve consentimento de gravação, retenção
e conformidade com LGPD.

### LGPD

Implementado e auditado:

- Art. 14 — consentimento específico do responsável, por finalidade
- Art. 18 §V — portabilidade (`exportUserData`, JSON estruturado)
- Art. 18 §VI — eliminação (`requestDataDeletion`, 15 dias de carência)
- Art. 18 §IX — revogação por finalidade
- Art. 16 §I — retenção do prontuário por 20 anos (CFM 1.821/2007), com
  anonimização em vez de exclusão

**Falta:** designar o Encarregado de Dados e publicar o contato. O manifesto
serve `privacidade@pediatria360.app` — trocar pelo endereço real.

---

## 4. Infraestrutura

```bash
# Regras — publique ANTES de qualquer dado real
firebase deploy --only firestore:rules,firestore:indexes,storage:rules

# Segredos
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set BUNNY_STREAM_API_KEY
firebase functions:secrets:set BUNNY_TOKEN_KEY

firebase deploy --only functions
```

**Confira:**
- [ ] Nenhuma chave no código do cliente (`tool/security_audit.py` verifica)
- [ ] `firebase_options.dart` gerado pelo `flutterfire configure`, não o
      arquivo de exemplo
- [ ] Regras publicadas — sem elas o Firestore fica aberto ou fechado, e
      nenhum dos dois serve
- [ ] Webhook do Bunny apontando para `bunnyWebhook`
- [ ] Função agendada `processScheduledDeletions` ativa (exclusões da LGPD)
- [ ] Função agendada `rebuildLeaderboard` ativa

---

## 5. Integrações pendentes

Documentadas no código, não escondidas. Cada uma tem erro explícito em vez de
falha silenciosa.

| Integração | Estado | Onde |
|---|---|---|
| **Gateway de pagamento** | Pedido é criado e estoque baixado em transação; `paymentUrl` retorna `null` | `functions/src/commerce.ts` |
| **Sala de vídeo** | Permissão e janela validadas; lança `unimplemented` | `functions/src/commerce.ts` |
| **Assinatura ICP-Brasil** | Campos prontos, provedor não integrado | `functions/src/emr.ts` |
| **Foto de perfil** | `uploadPhoto` existe no repositório, nenhuma tela chama | `children_repository_impl.dart` |

**Sobre o pagamento:** o status **nunca** pode vir do cliente. Quem muda para
`paid` é o webhook do gateway.

---

## 6. Build

### Antes de tudo

```bash
flutter create --platforms=android,ios,web \
  --org app.pediatria360 --project-name pediatria360 .
```

As pastas de plataforma não são versionadas — dependem da sua versão do
Flutter. Depois aplique os ajustes de `platform/` (ver `SETUP.md`, passo 2).

### Android

- [ ] `minSdk 23` — exigido pelo `firebase_auth`
- [ ] Multidex habilitado
- [ ] Plugin `google-services` aplicado
- [ ] **Chave de assinatura de release** — o `build.gradle.kts` de exemplo usa
      a de debug. ⛔ Trocar antes de publicar.
- [ ] `google-services.json` do projeto de produção

### iOS

- [ ] Deployment target 13.0
- [ ] Textos de permissão específicos no `Info.plist` — genéricos fazem a
      App Store rejeitar
- [ ] Macros `PERMISSION_*` no Podfile (só as usadas)
- [ ] `GoogleService-Info.plist` de produção

### Web

- [ ] SDKs do Firebase no `index.html`
- [ ] Domínio autorizado no Firebase Auth

---

## 7. Lojas

### Ambas

- [ ] Política de privacidade publicada em URL pública
- [ ] Termos de uso
- [ ] Classificação indicativa
- [ ] Capturas de tela por tamanho de dispositivo
- [ ] Ícone em todas as resoluções

### Declaração de dados

As duas lojas exigem declarar coleta de dados. O que este app coleta:

- Dados de saúde (medições, vacinas, atendimentos, exames, prescrições)
- Identificação (nome, e-mail, telefone)
- Dados de criança — **exige tratamento específico nas duas lojas**
- Conteúdo enviado a provedor de IA quando a finalidade está consentida

### Categoria

Ambas as lojas têm políticas específicas para aplicativos de saúde. Um app que
registra prontuário e emite receita costuma exigir comprovação de vínculo com
profissional habilitado. Consulte antes de submeter — rejeição por categoria
custa semanas.

---

## 8. Observabilidade

- [ ] Crashlytics recebendo eventos (force um crash de teste)
- [ ] Analytics configurado
- [ ] `AppLogger` não vazando dado clínico nos logs — conferir manualmente
- [ ] Alertas de erro nas Cloud Functions
- [ ] Orçamento e alerta de custo no Firebase

---

## 9. Antes de gerar o build final

- [ ] `flutter analyze` sem erro ⛔
- [ ] `flutter test` verde ⛔
- [ ] Testes de regras verdes ⛔
- [ ] `tsc --noEmit` limpo ⛔
- [ ] Auditoria de segurança sem achado ⛔
- [ ] Tabelas da OMS substituídas ⛔
- [ ] Calendário do PNI conferido ⛔
- [ ] Chave de assinatura Android de release ⛔
- [ ] Encarregado de dados designado ⛔
- [ ] Testado em aparelho real, offline e online
- [ ] Testado em tablet
- [ ] Fluxo completo percorrido: cadastro → atendimento → assinatura →
      receita → PDF

---

## 10. O que não está pronto para produção

Registrado aqui para não haver surpresa:

1. **Nenhuma linha foi compilada.** 35 mil linhas escritas sem `flutter
   analyze`. Há erros de tipo, `await` esquecido e nulidade mal tratada — não
   sei quantos.
2. **Nenhum teste foi executado.** Os 223 casos foram escritos e as asserções
   conferidas numericamente à mão, mas o runner nunca rodou.
3. **Certificação SBIS/CFM não iniciada.**
4. **ICP-Brasil não integrado.**
5. **Pagamento e vídeo não integrados.**
6. **Protocolos SBP/AAP/PALS/NRP não incluídos** — são obras protegidas. O
   motor de protocolos está pronto; o conteúdo precisa vir licenciado.

O primeiro item é o mais urgente e o mais barato de resolver: suba o
repositório, deixe o CI rodar, e o `flutter analyze` responde em minutos.
