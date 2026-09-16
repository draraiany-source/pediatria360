> **HISTÓRICO — não é o documento atual.**
>
> Pendências categorizadas — conteúdo consolidado em BLOQUEADORES_PRODUCAO.md.
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

# PENDENCIAS_PRODUCAO.md — Pediatria 360

Cada item classificado numa categoria só, mesmo quando toca mais de uma —
a categoria é a que **bloqueia primeiro**.

---

## BLOQUEADOR

Nada disto pode ir ao ar como está.

| Item | Por quê |
|---|---|
| Nenhuma linha compilada | `flutter analyze`, `flutter test`, `npx tsc --noEmit`, testes de regra no emulador — nenhum rodou. Ver `tool/validate_release.sh`. |
| Curvas OMS aproximadas | `who_reference.json` não é a tabela oficial. Aviso agora visível na tela (corrigido nesta sessão), mas o dado em si continua aproximado. |
| Calendário PNI não conferido | Precisa validação contra gov.br/saude/vacinacao/calendario antes de publicar. |
| `firebase_options.dart` de exemplo | Projeto real via `flutterfire configure` — ver seção "Depende do proprietário". |
| Keystore Android de debug | Build de release não pode assinar com chave de debug. |
| Termos de Uso / Política de Privacidade | Documentos não existem — só URLs placeholder marcadas no código. Cadastro aponta para página que não existe ainda. |

## IMPORTANTE

Não impede lançamento técnico, mas compromete a experiência ou expõe risco
que vale corrigir antes.

| Item | Situação |
|---|---|
| Busca de CID por descrição | Só aceita código digitado manualmente — sem base oficial |
| `awardXp` por conclusão de artigo | Aula e curso completo já pontuam (v35 sequência); artigo exigiria converter `ContentDetailScreen` de stateless para stateful — adiado de propósito, não esquecido |
| `growthRecorded`/`vaccineMarked` no servidor, nunca chamados pelo cliente | Decisão deliberada, não esquecimento: o servidor já tem valor de XP configurado para essas duas ações (de uma rodada anterior a "não gamificar vacinação obrigatória"), mas o cliente nunca as chama. Manter assim — pontuar registro de vacina poderia incentivar marcar como aplicada pela recompensa, não pela realidade |
| Edição de foto de perfil | `image_picker` removido — sem upload funcional |
| Importação de laudo laboratorial | `parseLabText` funciona no servidor, sem tela |
| Cancelamento de teleconsulta pré-integração | Fluxo de agendamento em vídeo desativado por flag — ver "Depende de serviço externo" |
| Painel financeiro / gestão de clínica multi-unidade | Não existe — é módulo novo, não extensão |

## PÓS-LANÇAMENTO

Razoável não ter na v1.0.

- Ditado clínico por voz
- Modo hospitalar (enfermaria, balanço hídrico, UTI neonatal)
- Equipe multiprofissional com pareceres internos
- Telemonitoramento de pacientes crônicos
- Internacionalização (inglês/espanhol)
- Escalas de triagem validadas (TEA, TDAH) — dependem de licença de uso

## DEPENDE DO PROPRIETÁRIO

Marcado no código como `AGUARDANDO DADO DO PROPRIETÁRIO`, nunca inventado.

| Dado | Onde entra |
|---|---|
| CNPJ, razão social, endereço | Termos de Uso, Política de Privacidade |
| E-mail de suporte real | Hoje `suporte@pediatria360.app`, fictício, centralizado em `AppConfig` |
| E-mail e nome do encarregado de dados (LGPD) | Política de Privacidade, tela de privacidade do app |
| Domínio real | Termos/Política apontam para `pediatria360.app`, que não existe |
| Projeto Firebase de produção | `flutterfire configure` — `firebase_options.dart` atual é placeholder que falha alto de propósito (`isPlaceholder`) |
| Conta Google Play / App Store, dados de faturamento | Publicação nas lojas |
| Texto final de Termos de Uso e Política de Privacidade | Revisão jurídica — não escrevo texto legal sem qualificação para isso |
| Decisão sobre CRM/coordenação editorial dos protocolos SBP/AAP/PALS/NRP | Conteúdo protegido, precisa licença |

## DEPENDE DE SERVIÇO EXTERNO

Infraestrutura real que precisa ser contratada — nada disto pode ser
simulado sem virar propaganda enganosa.

| Serviço | Usado por | Estado atual |
|---|---|---|
| Provedor de videochamada (Daily.co, Twilio, Agora...) | Teleconsulta | `joinConsultation` já valida autorização real, lança `unimplemented` de propósito |
| Gateway de pagamento (Stripe, Mercado Pago, Pagar.me) | Loja, consulta paga | `createOrder` funciona, `paymentUrl` retorna `null`; checkout desabilitado com aviso, não erro |
| Certificado ICP-Brasil | Assinatura juridicamente válida de receita/atestado | Hoje só sela com hash — aviso explícito no PDF e na tela de que isso não é assinatura digital válida |
| Certificação SBIS/CFM | Prontuário eletrônico com validade plena | Processo de certificação formal, não é código |
| Base oficial de CID-10 | Diagnóstico no atendimento | Sem licença hoje |

---

## O que foi corrigido na v34

- Import quebrado em `clinical_pdf_service.dart` (`Target of URI doesn't exist` — falharia a compilação real)
- Aviso de curva OMS aproximada, invisível na tela, agora visível
- Mesmo problema no calendário PNI, mesma correção
- `professional_schedule.dart` identificado como sistema duplicado de um já
  existente e funcional (`getAvailability`) — marcado como superado
- 2 testes de regra novos confirmando quem pode escrever disponibilidade

## O que foi corrigido na v35

- **Inconsistência entre relatórios corrigida** — `AUDITORIA_FINAL.md`
  dizia que este arquivo e `CHECKLIST_PUBLICACAO_FINAL.md` "ainda não
  existiam", numa frase que sobreviveu de antes de eu criá-los na mesma
  entrega. Contagem de teste de regra (48→50) também estava desatualizada
  em 6 lugares diferentes — corrigido em todos.
- **`professional_schedule.dart` removido** (não só marcado como superado).
  Confirmado zero uso real fora de teste antes de apagar.
- **Agenda profissional concluída**: `TelemedicineRepository` ganhou
  leitura/escrita de disponibilidade, `confirm()`/`markCompleted()`;
  `AppointmentType` (presencial/teleconsulta) adicionado; tela real de
  agenda construída, com "Iniciar atendimento" ligando ao prontuário para
  consulta presencial.
- **Erro cometido e corrigido na mesma sessão**: o arquivo novo da agenda
  tinha todo import com um `../` a mais — pego pela própria
  `tool/check_imports.py`, criada na v34 depois de um erro do mesmo tipo.
