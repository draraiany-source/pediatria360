# Etapa 3 — Arquitetura modular (contratos)
**Data:** 15/11/2026  
**Branch:** `audit/modulos-integracao-20261115`  
**Status:** proposta documentada. **Nenhuma alteração de comportamento do app nesta etapa.**

Princípio: um único aplicativo Pediatria 360; três módulos lógicos; sem segundo projeto Flutter salvo necessidade técnica comprovada e aprovada.

---

## 1. Visão dos módulos

```text
Shell + Auth + clinic_org + Remote Config + App Check
├── M1 Gestão clínica (existente)
├── M2 Tia Cris — receptionist_ai (estender)
└── M3 Espaço Kids 360 — kids_space (novo, isolado)
```

| Módulo | Pacote / feature | Rotas | Pode ver clínico? |
|---|---|---|---|
| M1 | `emr`, `clinic`, `children`, `finance`, … | existentes | Sim, conforme papel/grant |
| M2 | `receptionist_ai` (+ callables novos) | `/recepcionista-ia` (+ subrotas futuras) | **Não**, salvo necessidade operacional explícita (hoje: não) |
| M3 | `kids_space` (**novo**) | `/kids/*` | **Nunca** |

---

## 2. Contratos entre módulos

### 2.1 M1 — plataforma
- Dono das entidades clínicas: `children`, `encounters`, `clinical_documents`, `appointments`, grants, finance.
- Escritas clínicas continuam nas Functions existentes (`emr`, `scheduling`, `finance`, …).
- UI das telas atuais **não** muda sem autorização.

### 2.2 M2 Tia Cris → M1 (somente administrativo)

**Permitido consumir (via callables / UI já autorizada à recepção):**
- `getScheduleSlots`, `scheduleAppointment`, `setAppointmentStatus` (balcão)
- Intakes / cadastro básico (`clinicFlow`)
- Preferências de comunicação / fila não clínicas (quando liberadas)
- Encaminhar para humano (agenda/recepção existente)

**Proibido:**
- Ler/escrever `encounters`, voz EMR, prescrições, anexos de anamnese clínica
- Diagnosticar, prescrever ou inventar horários/preços/profissionais
- Contornar Auth ou rules (demo sem login só em `main_demo`, separado)

**Persona vs assistente clínico:**
- Tia Cris ≠ `/ia` ≠ `clinicalAssist` ≠ `/gestao/ia`
- Permissões e prompts separados

### 2.3 M3 Kids → M1

**Permitido:**
- Sessão de sala de espera com código/token de clínica **sem** PII clínica
- Progresso de jogos em coleções próprias
- Áudio/efeitos locais

**Proibido:**
- Prontuário, vacina clínica, receita, financeiro, chat IA clínico
- Exigir dados pessoais da criança para jogar
- Ads, chat entre usuários, ranking público com dados de menores

**Futura comercialização:** `lib/features/kids_space/` com dependências mínimas; **não** criar segundo app agora.

---

## 3. Isolamento de dados (proposto)

### Coleções novas (somente Kids) — nomes provisórios
- `kids_waiting_sessions` — sessão kiosk, `clinicId`, expiração, sem chart
- `kids_play_progress` — progresso por sessão/jogo

### Coleções existentes
- **Não modificar schema** de `encounters`, `appointments`, `children` para Kids
- Tia Cris **não** ganha rules novas de leitura clínica

### Storage
- Kids: `kids/{clinicId}/sessions/{id}/**` (quando Storage existir)
- Sem acesso a `care/{childId}` ou `anamnesis/`

---

## 4. Rotas e autorização

| Path | Módulo | Quem |
|---|---|---|
| `/consultorio`, `/agenda`, … | M1 | papéis atuais |
| `/recepcionista-ia` (+ futuras) | M2 | admin, clinicAdmin, receptionist |
| `/kids`, `/kids/play/:game`, `/kids/kiosk` | M3 | kiosk (token/sessão) ou staff no tablet |

Implementação futura deve espelhar `canOpenRoute` / `resolveRouteRedirect` — **não** só esconder menu.

---

## 5. Feature flags (propostas — default desligado)

Documentação apenas. **Ainda não adicionadas ao código.**

### Remote Config
| Key | Default | Efeito |
|---|---|---|
| `tia_cris_enabled` | `false` | Ativa atendimento automático Tia Cris |
| `tia_cris_booking_enabled` | `false` | Agendar via persona (callables M1) |
| `kids_space_enabled` | `false` | Libera `/kids/*` |
| `kids_kiosk_enabled` | `false` | Modo sala de espera |

### AppConfig (compile-time)
| Flag | Default sugerido |
|---|---|
| `tiaCrisRuntimeEnabled` | `false` |
| `kidsSpaceRuntimeEnabled` | `false` |

---

## 6. Ordem de implementação segura

1. Flags + rotas Kids vazias / placeholder kiosk  
2. Jogos offline + áudio + testes de isolamento  
3. Rules das coleções Kids  
4. Tia Cris: FAQ/horários determinísticos + handoff humano  
5. Tia Cris: agendamento só reutilizando callables M1  
6. Homologação com flags off; ligar por ambiente  

---

## 7. Testes de contrato

| # | Teste | Critério |
|---|---|---|
| C1 | Recepção não abre chart | redirect/deny |
| C2 | Token Kids não lê `encounters` | deny nas rules |
| C3 | Tia Cris não chama `clinicalAssist` / voice EMR | ausente no cliente M2 |
| C4 | Agendamento via M2 = invariants de `scheduling` | e2e emulador |
| C5 | Flag off ⇒ Kids/Tia inacessíveis | redirect |
| C6 | Regressão booking família/recepção | testes existentes |

---

## 8. Fora de escopo até nova aprovação

- Implementar jogos ou backend Tia Cris (Etapas 4–5)
- Alterar visual das telas clínicas atuais
- Ligar WhatsApp/pagamento/ICP/TISS/vídeo
- Segundo repositório/app Kids
