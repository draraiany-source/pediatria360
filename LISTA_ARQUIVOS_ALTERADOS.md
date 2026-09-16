> **HISTÓRICO — não é o documento atual.**
>
> Lista de arquivos alterados da v39 — este conteúdo já vive na tabela de cada CHANGELOG_VXX.md.
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

# LISTA_ARQUIVOS_ALTERADOS.md — v39

Escopo: só esta rodada. Para o histórico completo de versões anteriores,
ver `CHANGELOG_V35.md` e os relatórios anteriores — não repito aqui para
não duplicar informação que já existe em outro lugar e arriscar as duas
cópias divergirem com o tempo, o mesmo problema que já corrigi entre
relatórios em rodadas passadas.

## Modificados

| Arquivo | Mudança |
|---|---|
| `lib/core/router/app_router.dart` | Guarda de rota profissional-only (`/pacientes`, `/agenda`) no `redirect`, mesmo padrão já usado para `/admin` |
| `ANTES_DE_COMPILAR.md` | Seção de verificação de rotas atualizada com o achado da guarda de perfil ausente |

## Criados

| Arquivo | Propósito |
|---|---|
| `CHANGELOG_V40.md` | Changelog desta versão |
| `BLOQUEADORES_COMPILACAO.md` | Bloqueadores de compilação, por dependência (Flutter/Firebase/Android/iOS) |
| `BLOQUEADORES_PRODUCAO.md` | Bloqueadores de produção, nas 9 categorias pedidas |
| `LISTA_ARQUIVOS_ALTERADOS.md` | Este arquivo |

## Não modificados nesta rodada

Nenhum outro arquivo do projeto foi tocado — sem novo módulo, sem nova
tela, sem alteração de arquitetura ou design, conforme pedido.
