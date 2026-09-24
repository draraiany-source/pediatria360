# Consulta e indice: users/{uid}/consents.grantedAt

## Consulta (app)

Arquivo: `lib/features/security/data/consent_history_repository.dart`

```
users/{uid}/consents
  .orderBy('grantedAt', descending: true)
  .limit(50)
```

Escopo: colecao unica sob o documento do usuario (nao e collection group).

## Indice correspondente

Campo unico `grantedAt` (DESC) em `users/{uid}/consents`.

Firestore cria automaticamente indices single-field para orderBy em um unico campo.
Nao e necessario entrada composta em `firestore.indexes.json` para esta consulta.

Se no futuro a consulta passar a combinar filtros (ex.: `where('type' == X) + orderBy('grantedAt')`),
adicionar indice composto:

```json
{
  "collectionGroup": "consents",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "type", "order": "ASCENDING" },
    { "fieldPath": "grantedAt", "order": "DESCENDING" }
  ]
}
```

Status FASE 9 closeout: documentado; indice composto NAO requerido pela consulta atual.
