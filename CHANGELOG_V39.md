> **HISTÓRICO — não é o documento atual.**
>
> Changelog da versão 39 — correção de lacuna de proteção de rota
> `/pacientes`/`/agenda` no roteador (sem teste na época; os testes foram
> adicionados na v40).
>
> Para o estado atual do projeto, use:
> - `README.md` — visão geral
> - `ANTES_DE_COMPILAR.md` — o que verificar/rodar antes da primeira compilação real
> - `BLOQUEADORES_PRODUCAO.md` — o que falta para produção, categorizado
> - `CHECKLIST_PUBLICACAO_FINAL.md` — checklist de publicação
> - `CHANGELOG_V40.md` (ou o mais recente) — o que mudou, versão a versão
>
> Este arquivo fica como registro do que foi decidido e por quê — não é
> atualizado desde que virou histórico.

---

# CHANGELOG_V39.md — Pediatria 360

## Contexto

Terceira rodada seguida de revisão preventiva sem funcionalidade nova.
Cada rodada anterior achou algo real ao olhar com cuidado — esta não foi
diferente: uma lacuna de roteamento por perfil que as duas rodadas
anteriores não tinham verificado.

## O que foi corrigido nesta versão

- **Lacuna de roteamento por perfil.** O `redirect` do `GoRouter` já
  bloqueava `/admin` para quem não é admin, mas não tinha proteção
  equivalente para `/pacientes` e `/agenda` (área do profissional). Um
  responsável navegando direto para essas rotas — link salvo, digitado na
  Web — não era barrado no roteador; ficava protegido só pelas regras do
  Firestore, que devolveriam lista vazia. Sem vazamento de dado, mas uma
  tela sem sentido nenhum para quem chegasse nela. Corrigido com o mesmo
  padrão já usado para admin — e a checagem também bloqueia admin da área
  clínica, consistente com a regra já estabelecida de que administração
  não tem acesso clínico irrestrito.
- Verificado e confirmado sem problema: classes públicas duplicadas entre
  arquivos (zero, em 384), colisão de prefixo de rota (nenhuma).

## Arquivos modificados

| Arquivo | O que mudou |
|---|---|
| `lib/core/router/app_router.dart` | Guarda de rota profissional-only, mesmo padrão do admin |
| `ANTES_DE_COMPILAR.md` | Seção de rotas atualizada com este achado |

## Arquivos criados nesta versão

- `BLOQUEADORES_COMPILACAO.md`
- `BLOQUEADORES_PRODUCAO.md`
- `LISTA_ARQUIVOS_ALTERADOS.md`
- `CHANGELOG_V40.md` (este arquivo)

## Testes

Nenhum teste novo nesta versão — a correção é de lógica de roteamento em
tempo de execução (`GoRouter.redirect`), que não tem cobertura de teste
unitário estabelecida no projeto (testar `redirect` exigiria simular
`GoRouterState`/`BuildContext`, infraestrutura que não existe aqui ainda).
Registrado como lacuna, não escondido.

228 testes Dart + 63 de regra — sem mudança de número desde a v38.

## Não afirmado nesta versão

- Não digo "compilou" — nenhuma linha rodou em Flutter real
- Não digo "100% pronto"
- Não digo "todos os testes passaram" — os 228 + 63 foram escritos e as
  asserções verificadas manualmente, execução real pendente
