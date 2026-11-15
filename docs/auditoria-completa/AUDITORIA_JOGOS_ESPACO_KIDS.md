# AUDITORIA JOGOS — Espaço Kids

**Data:** 15/11/2026 (America/Sao_Paulo)  
**Módulo:** `lib/features/kids_space/`  
**Rotas:** `/kids`, `/kids/play/:gameId`, `/kids/responsavel`, `/kids/kiosk`  
**Flag:** `KIDS_SPACE_ENABLED` (default off); kiosk separado

## Jogos (engines determinísticos)

| ID | Título UI | Isolamento clínico | Testes |
|---|---|---|---|
| memory | Memória do Ursinho | sim | FT kids_space |
| puzzle | Quebra-cabeça da Tia Cris | sim | FT |
| hygieneFood | Pequeno Doutor | sim | FT |
| colorsShapes / numbersLetters / attention | demais catálogo | sim | FT |

Persistência: `kids_play_progress` (+ local). Rules proíbem campos clínicos.

## Acessibilidade / pausa
- Home: chips “Do seu jeito” (`kidsAccessibilityProvider` sessão)
- Banner pausa → área responsável (limite diário / mute)
- Nível no card **ainda não** altera parâmetros do engine (P2)

## Isolamento
Kids **não** importa encounters/prescriptions. Confirmado por arquitetura Etapa 4/5 e rules.

## Pendências
- Flag off default
- Ilustrações 3D do mockup ausentes
- Kiosk NT UI
