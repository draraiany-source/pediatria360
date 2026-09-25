# FASE 2 — ponto de recuperacao (pre-implementacao)

- Branch/commit base: `bdf3ef760cfa3da0da7500fbc1b59010984e0939` (origin/main)
- Recuperacao: `git checkout bdf3ef7 -- .` ou `git reset --hard bdf3ef7` (somente se autorizado)
- Nao houve migracao destrutiva de dados de producao nesta fase
- Novas subcollections (nao substituem `users/{uid}/children`):
  - `.../children/{childId}/guardians/{guardianUid}`
  - `.../children/{childId}/change_log/{id}`
  - `users/{uid}/linked_children/{childId}`
  - `clinics/{clinicId}/rooms/{roomId}`
  - `clinics/{clinicId}/schedule_blocks/{blockId}`
  - `appointments/{id}/change_log/{id}`