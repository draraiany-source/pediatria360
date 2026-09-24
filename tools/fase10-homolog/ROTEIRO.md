# Roteiro FASE 10 — por perfil (dados ficticios)

## Comum a todos
1. Abrir app (Chrome/Edge + Emulator)
2. Login com email/senha da tabela
3. Navegar home/menus permitidos
4. Botao voltar / sair (logout)
5. Confirmar persistencia via Emulator UI ou `run_matrix.js`

## Administrador (clinicAdmin A)
- Selecionar clinica Homolog A em /clinica
- Abrir /permissoes (matriz) — atribuir/revogar se UI permitir escrita
- Abrir /auditoria — ver logs; NAO abrir prontuario de paciente alheio
- Negativo: com admin B, tentar ler finance/audit da clinica A (esperado: negado)

## Recepcao
- Cadastro paciente (se fluxo UI existir) / ver crianca ficticia autorizada
- Agendar/remarcar/cancelar — se rules de appointments limitarem a professionalId, documentar limite
- Check-in em /consultorio/recepcao
- Negativo: escrita financeira

## Medico
- Abrir agenda propria
- Abrir/criar encounter draft; salvar
- Assinatura: requer Functions `signEncounter` — se Functions off, NAO TESTADO
- Verificar imutabilidade de encounter assinado (rules)

## Financeiro
- /financeiro/receber — criar/consultar cobranca ficticia
- Filtros clinica/unidade via membership
- Sem pagamento real (paymentGatewayEnabled=false)

## Paciente/responsavel
- Login; ver propria crianca; consentimentos
- Negativo: crianca familia B; financeiro clinico

## Android / iOS (quando houver aparelho)
1. `flutter devices` deve listar o aparelho/emulador
2. Mesmos dart-defines de Emulator (EMULATOR_HOST=10.0.2.2 no Android emulador)
3. Repetir roteiros Admin → Paciente
4. Registrar PASSOU/FALHOU por cenario