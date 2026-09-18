# Auditoria ? Redesign Premium Pediatria360

Data: 2026-09-18
Referencias: `C:/Users/Lenovo/Downloads/ped/*.png` (6 telas Home SaaS)

## Estado atual (antes do redesign)

### Navegacao
- Shell com bottom nav (mobile), NavigationRail (tablet), Sidebar (desktop)
- Profissional: Inicio | Consultorio | Agenda | Mensagens | Perfil
- Familia: Inicio | Conteudos | Cuidados | Mensagens | Perfil
- Pacientes / Vacinas / Telemedicina / Biblioteca acessados via atalhos

### Design system existente
- `app_colors.dart` ? azul clinico #315EF5, navy, teal (ja alinhado as refs)
- `app_tokens.dart` ? spacing/radius (lg=20)
- `app_typography.dart` ? Nunito
- `brand_ui.dart` / `clinical_ui.dart` / `state_views.dart`

### Funcionalidades maduras
Home, Pacientes/EMR, Agenda, Vacinas, Crescimento, Notificacoes, Clinic 360, Suplementacao

### Parcial / stub
Video telemedicina, KPIs clinic, Settings `/ajustes` sem tela, Help snackbar, Financeiro/Relatorios inexistentes

## Estrategia (sem reconstruir)
1. Etapa 1: tokens + sidebar premium + top bar + Home (esta entrega)
2. Etapa 2: Pacientes
3. Etapa 3: Perfil paciente / Prontuario
4. Demais telas na ordem do prompt

## Decisao visual das referencias
- Sidebar clara (padrao dominante nas refs claras) com item ativo azul solido
- KPI com indicador de tendencia
- Acesso rapido em 5 cards compactos
- Agenda timeline + Atencao necessaria lado a lado no desktop
- Dados reais do app (sem mocks permanentes de numeros inventados)
