# PENDÊNCIAS PRIORIZADAS

**Data:** 15/11/2026 (America/Sao_Paulo)

## P0 — bloqueia uso seguro com dados reais
| ID | Item | Estado | Ação |
|---|---|---|---|
| P0-1 | Publicar com flags M2/M3 e voice sem plano de homolog | Aberto | Manter flags off até checklist |
| P0-2 | Integrações essenciais (Auth real, rules em produção) sem revalidação completa | Aberto | Reexecutar rules emulator + smoke |
| P0-3 | Storage/Blaze / uploads clínicos | BLQ | Infra Firebase |

## P1 — alto
| ID | Item | Estado | Ação |
|---|---|---|---|
| P1-1 | Profissional x growth/vacinas família | **Mitigado** | Gate GrowthScreen + mensagem 360 (FASE2) |
| P1-2 | Convidado SKIP_AUTH mensagem/permissoes | Mitigado codigo | Retestar UI |
| P1-3 | Grant child access ownerUid enumeration | WIP commit pendente | Commitar WIP + testes rules |
| P1-4 | IDOR multi-clínica e2e | NT | Emulator script |
| P1-5 | Voice IA sem consentimento | Verificar rotas | Garantir guardas |
| P1-6 | Tia Cris / Kids flags em homolog | Aberto | Channel flags apenas |

## P2 — médio
| ID | Item |
|---|---|
| P2-1 | Modelos de receita persistentes |
| P2-2 | Diário infantil rota dedicada |
| P2-3 | Nível Kids sem efeito no engine |
| P2-4 | Export/import/print crescimento |
| P2-5 | Suíte Flutter completa não reexecutada |

## P3 — visual / baixa
| ID | Item |
|---|---|
| P3-1 | Ilustrações 3D Tia Cris/urso dos mockups |
| P3-2 | Polimento tipográfico/const infos analyze |

## Não fazer sem autorização
- Afrouxar `firestore.rules` de growth/vaccines
- Deploy produção / lojas
- WhatsApp ou cobrança real
- Reset/limpeza destrutiva
