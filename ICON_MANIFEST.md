# ICON_MANIFEST.md — Pediatria 360

Os 16 ícones dimensionais de módulo, gerados por `tool/generate_module_icons.py`
— não são renderização 3D, são SVG com gradiente diagonal, brilho na metade
superior e sombra projetada, técnica que dá volume sem depender de bitmap.

**Fonte única de verdade: o script.** Os arquivos em `assets/icons/modules/`
são gerados, não editados à mão — mudar um ícone significa mudar a função
`symbol_*()` correspondente no script e rodar `python3
tool/generate_module_icons.py` de novo.

## Onde usar, e onde não usar

Só nos cartões grandes (56px+) voltados à família/visão geral — Home,
Caderneta Digital, entrada de módulo. Nas telas clínicas densas (lista de
pacientes, prontuário, agenda em linha) continuam sendo `Icons.*` do
Material, planos, 16–24px: nesse tamanho, volume vira borrão, e quem varre
uma lista precisa de reconhecimento instantâneo, não de estilo.

## Os 16

| Nome do arquivo | `aria-label` | Cor (escura/clara) | Símbolo | `AppColors` |
|---|---|---|---|---|
| `growth.svg` | growth | `#2E7D8A` / `#4FA8B8` | linha de curva com ponto | `moduleGrowth` |
| `vaccines.svg` | vaccines | `#0E6E52` / `#2FA37D` | seringa | `moduleVaccines` |
| `library.svg` | library | `#7A3F8F` / `#A96BBF` | livro aberto | `moduleLibrary` |
| `ai.svg` | ai | `#1B5E86` / `#4A9BC7` | faísca | `moduleAi` |
| `courses.svg` | courses | `#A8501E` / `#D98B4A` | play | `moduleCourses` |
| `shop.svg` | shop | `#9C2A54` / `#D45C86` | sacola | `moduleShop` |
| `telemedicine.svg` | telemedicine | `#155E75` / `#3FA3BF` | câmera | `moduleTelemedicine` |
| `gamification.svg` | gamification | `#A67C00` / `#E0B94A` | medalha | `moduleGamification` |
| `emr.svg` | emr | `#14676B` / `#3E979B` | prontuário | (usa `petrol`) |
| `tools.svg` | tools | `#4A5568` / `#8595AB` | calculadora | (usa cinza neutro) |
| `agenda.svg` | agenda | `#B36A00` / `#F5A623` | calendário | `moduleAgenda` |
| `development.svg` | desenvolvimento | `#8A2F6E` / `#C15FA0` | estrela de marco | `moduleDevelopment` |
| `exams.svg` | exames | `#0E6E82` / `#22B8D6` | tubo de ensaio | `moduleExams` |
| `medications.svg` | medicamentos | `#5B3FA8` / `#9B7FE0` | cápsula | `moduleMedications` |
| `allergies.svg` | alergias | `#A8241A` / `#EF5A4C` | alerta | `moduleAllergies` |
| `administration.svg` | administração | `#3D4552` / `#6B7686` | engrenagem | `moduleAdministration` |

## Os 6 últimos (nesta rodada)

Os 10 primeiros já existiam. `agenda`, `development`, `exams`,
`medications`, `allergies`, `administration` foram desenhados agora,
completando a cobertura dos módulos que o produto já usa mas ainda não
tinham ícone dimensional algum.

Cor de cada um escolhida para não repetir nenhuma das 10 já em uso — mais
próximo disso: `agenda` (`#B36A00`, âmbar) é vizinho de `courses`
(`#A8501E`, laranja terroso), mas os dois são visualmente distintos lado a
lado. Nenhuma cor duplicada.

Duas correções feitas antes de considerar pronto:

- **Estrela de `development`**: a primeira versão tinha coordenada
  estimada a olho, levemente assimétrica. Gerada matematicamente (centro,
  raio externo, raio interno, ângulo de 36° entre pontas) antes de virar
  arquivo final.
- **Engrenagem de `administration`**: o traço pontilhado do anel externo
  precisa fechar num número inteiro de dentes, ou a costura fica visível.
  `stroke-dasharray="6.28 6.28"` foi calculado a partir da circunferência
  real do círculo (raio 16, 8 dentes), não estimado.

## Verificado nos 16, não assumido

- Todos com o mesmo `viewBox="0 0 96 96"`
- Nenhum com fundo branco sólido (halo) atrás do símbolo
- Nenhum nome duplicado
- Todos válidos como XML
- Peso total: 21,1 KB para os 16 — SVG em vez de bitmap, mantém nitidez em
  qualquer densidade de tela e pesa menos que um único PNG @3x do conjunto
