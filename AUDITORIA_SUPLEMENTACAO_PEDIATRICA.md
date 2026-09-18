# Auditoria — Suplementacao Pediatrica

## Escopo entregue
- Dashboard premium com busca, modulos, favoritos e recentes
- 16 micronutrientes com secoes estruturais (conteudo pendente de validacao)
- Central de exames + registro + flag visual (sem auto-diagnostico)
- IA local de organizacao (exames + assistente) com disclaimer
- Calculadora sem doses numericas + fluxo Revisar e gerar prescricao
- Prescritor com rascunho e confirmacao obrigatoria
- Protocolos, alimentos, orientacao aos pais, historico, graficos, favoritos
- Integracao: Inicio, Paciente 360, rotas GoRouter, RBAC profissional
- Firestore paths + rules + auditoria de escrita
- Catalogo local preparado para CMS/admin (`supplementation/**`)

## Seguranca clinica
- Sem doses/limites/protocolos numericos inventados
- Placeholder: "Conteudo pendente de validacao medica."
- Disclaimer em telas clinicas e IA
- Responsavel so le prescricoes confirmadas (rules)

## Pendencias
- Exportacao PDF real / compartilhar nativo
- STT (voz) e anexo PDF/imagem de exames
- Admin CMS UI para editar catalogo
- Indexes Firestore compostos (childId + recordedAt / examId)
- Deploy rules/functions
- Revisao medica do conteudo antes de publicacao
