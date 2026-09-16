# BLOQUEADORES_PRODUCAO.md — Pediatria 360

Separado exatamente como pedido, nas 9 categorias.

---

## Firebase real

- `firebase_options.dart` de exemplo — `flutterfire configure` com
  projeto de produção
- `.firebaserc` vazio neste checkout — `firebase use --add`
- Regras (`firestore.rules`, `storage.rules`) e índices
  (`firestore.indexes.json`) prontos para deploy, mas **nunca publicados**
  — publicar antes de qualquer dado real entrar no banco, não depois
- SHA-1/SHA-256 cadastrados para Login Google no Android
- Domínio autorizado no Firebase Auth para a versão Web
- App Check — mencionado em rodadas anteriores como item a configurar,
  não implementado

## Dados legais

- CNPJ, razão social, endereço — `AGUARDANDO DADO DO PROPRIETÁRIO`
- E-mail de suporte real (hoje `suporte@pediatria360.app`, fictício,
  centralizado em `AppConfig`) — `AGUARDANDO DADO DO PROPRIETÁRIO`
- E-mail e nome do encarregado de dados (LGPD) — `AGUARDANDO DADO DO
  PROPRIETÁRIO`
- Domínio real (hoje `pediatria360.app`, não existe) — `AGUARDANDO DADO DO
  PROPRIETÁRIO`
- Texto final de Termos de Uso e Política de Privacidade — não escrevo
  texto legal sem qualificação para isso; hoje só existe URL placeholder,
  marcada como tal no código

## OMS

`assets/data/who_reference.json` é aproximado, não a tabela LMS oficial.
Aviso já visível na tela de crescimento (corrigido numa rodada anterior —
antes existia só como metadado de JSON que nenhum código lia). O dado em
si continua bloqueado para uso clínico até ser substituído pela tabela
oficial, com fonte, versão e data de revisão registradas.

## PNI

`lib/features/vaccines/domain/pni_calendar.dart` precisa ser conferido
contra gov.br/saude/vacinacao/calendario antes de publicar. Mesmo padrão
de aviso visível já aplicado na tela de vacinas.

## CID

Busca por descrição não implementada — só aceita código digitado
manualmente. Não invento base de CID; arquitetura preparada para receber
fonte oficial/licenciada quando disponível, sem funcionar de verdade até lá.

## Signing

- Keystore de release Android — hoje só assinatura debug
- `key.properties` fora do controle de versão — confirmar antes do
  primeiro build de release
- Certificado e provisioning profile de distribuição iOS

## Telemedicina

`AppConfig.videoConsultationEnabled = false`. `joinConsultation` já valida
autorização real (só paciente/profissional do agendamento específico),
lança `unimplemented` de propósito — sem provedor de vídeo contratado
(Daily.co, Twilio, Agora ou equivalente). Estrutura de agendamento
(confirmar, cancelar, disponibilidade) é real e funcional desde a v35;
só a chamada de vídeo em si está bloqueada.

## Pagamentos

`AppConfig.paymentGatewayEnabled = false`. `createOrder` funciona
(inclusive baixa de estoque em transação), `paymentUrl` retorna `null` —
sem gateway contratado (Stripe, Mercado Pago, Pagar.me ou equivalente).
Nenhum checkout falso — botão desabilitado com aviso antes do toque, não
erro depois.

## ICP-Brasil

`signEncounter` sela o registro (hash de integridade, bloqueio de edição,
histórico de retificação). **Isso não é assinatura ICP-Brasil.** Aviso
disso já existe no PDF e na tela de visualização do documento, enquanto
`signatureProvider`/`externalSignatureId` continuarem nulos. Certificação
SBIS/CFM também não iniciada — processo formal, não é código.

---

Lista completa de pendências menores (não-bloqueadoras) em
`PENDENCIAS_PRODUCAO.md`.
