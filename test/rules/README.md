# Testes das regras de segurança

Provam, com o emulador do Firestore, que as regras em `firestore.rules`
realmente isolam os dados — em vez de apenas afirmar isso num comentário.

## Rodar

```bash
npm install
npm test
```

O `firebase emulators:exec` sobe o emulador, roda os testes e derruba tudo.
Não toca em nenhum projeto real.

## O que é verificado

**Prontuário da criança** — o caso mais crítico. Nem outro responsável, nem
médico verificado, nem admin conseguem ler os dados de saúde da filha da Ana.
Só a própria mãe.

**Escalada de privilégio** — usuário não se dá plano premium, não se dá XP,
não vira admin e, principalmente, **profissional não se autoverifica** (é o
gate que libera posologias).

**Conteúdo de prescrição** — responsável não lê protocolo com posologia;
profissional que declarou CRM mas não passou pela conferência também não.

**Forja de resposta da IA** — ninguém escreve uma mensagem com `role:
"assistant"`. Sem essa regra, seria trivial fabricar "a IA disse que pode dar
esse remédio".

**Preço do pedido** — cliente não cria pedido nem marca como pago. Cupons não
são legíveis (listá-los revelaria todos os códigos ativos).

**Receita médica** — só paciente e prescritor. Nem o admin.

**Fechamento por padrão** — uma collection nova nasce fechada, em vez de
nascer pública por esquecimento.

## Se um teste falhar

Uma falha aqui significa que **as regras deixaram passar algo que não
deveriam**, ou que ficaram restritivas demais e vão quebrar uma tela. Leia o
nome do teste: cada um descreve o ataque ou o fluxo legítimo em questão.
