# Etapa 1 — Identidade visual, menu por perfil e paciente em foco

Data: 14/11/2026. Branch `audit/mestre-20261114`. Ambiente de verificação:
emuladores locais (projeto `demo-pediatria360`), contas e pacientes fictícios.

## O que mudou

| Item | Situação | Evidência |
|---|---|---|
| Paleta roxo/rosa/lavanda (`AppColors`) aplicada ao app inteiro | FV [UI] | `e1-01`, `e1-07` |
| Menu lateral roxo em degradê, item ativo rosa, logotipo `logo_light.png` | FV [UI] | `e1-01` |
| Menu de 15 módulos, filtrado pela mesma regra do roteador (`canOpenRoute`) | FV [TESTE] [UI] | `main_menu_test.dart`; `e1-01` (médica, 14 itens), `e1-07` (recepção, 5 itens) |
| Item ativo acompanha a rota (inclusive `aria-current` para leitor de tela) | FV [TESTE] [UI] | `main_menu_test.dart`; conferido no DOM |
| Papel real no cabeçalho e no menu (recepção deixou de aparecer como "Área da família"; profissional sem especialidade deixou de aparecer como "Pediatra") | FV [TESTE] [UI] | `e1-07` |
| Menu do cabeçalho: unidade ativa, perfil, ajustes, sair | PAR | Implementado; não aberto na verificação |
| Busca do cabeçalho só para quem acessa Pacientes | FV [UI] | `e1-07` (recepção sem busca) |
| Paciente em foco: escolha, permanência entre módulos, troca com confirmação de nome e nascimento | FV [UI] | `e1-02`, `e1-03`, `e1-04`, `e1-05` |
| Paciente em foco zera ao trocar de conta ou de clínica | FV [UI] | `e1-07` (sem paciente após trocar para a recepção) |
| Celular: barra inferior + gaveta com o menu completo | FV [UI] | `e1-05`, `e1-06` |
| Aba Tia Cris — Recepcionista IA (escopo e limites; sem conversa simulada) | PAR | `e1-08`. Atendimento automático não existe no servidor |
| Rota da Tia Cris: só gestão da clínica, recepção e administrador | FV [TESTE] | `main_menu_test.dart` |
| Módulos do paciente por URL bloqueados para a recepção | FV [TESTE] [UI] | Recepção em `/consultorio/modulo/prontuario` volta ao início |

## Destinos provisórios (aviso visível na tela)

Vacinação, Crescimento, Prescrições e documentos, Puericultura e
Multidisciplinar abrem o Paciente 360 do paciente escolhido, com aviso na tela
de seleção. Exames abre a tela de exames com o paciente.

## Achados

1. **Vacinas e Crescimento pela clínica ficam carregando sem fim.** A lista de
   pacientes do profissional usa o uid do responsável como `childId`; as telas
   de vacinas e crescimento são da área da família e procuram uma criança com
   esse id. O cartão "Vacinas" do Paciente 360 tem o mesmo problema. Correção
   prevista na Etapa 5. Até lá, o menu não leva a essas telas.
2. Na suíte completa (`flutter test`), três testes de
   `demo_sleep_wellchild_test.dart` não terminaram; o arquivo isolado passa
   9/9. Não investigado nesta etapa.

## Pendências externas

- Ilustração da Tia Cris: nenhum arquivo no projeto. A área tem tamanho fixo
  (`TiaCrisAssets.portrait`) e mostra "Ilustração pendente".
- Atendimento automático da Tia Cris: depende da Etapa 10 (servidor).

## Testes

- `test/features/shell/main_menu_test.dart`: 14/14.
- Goldens `capi_widgets_golden_test.dart` atualizados para a nova paleta
  (mesmo layout, só a cor mudou).
- `flutter test` completo: 909 aprovados; 2 goldens (atualizados depois) e
  3 testes que não terminaram na suíte (ver achado 2).
- `flutter analyze` nos arquivos alterados: sem erros nem avisos.
