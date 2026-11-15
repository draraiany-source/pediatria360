/**
 * Cria child_registry/{childId} = { ownerUid } para as criancas que ja
 * existem em users/{uid}/children/{childId}.
 *
 * Precisa rodar ANTES de publicar a versao de firestore.rules que usa o
 * registro em ownsChild(): sem o registro, as criancas antigas continuam no
 * caminho legado (inseguro) e uma nova crianca com o mesmo id poderia ser
 * registrada por outra pessoa.
 *
 * Padrao: simulacao (nao grava). Use --apply para gravar.
 *
 * Emulador:
 *   set FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
 *   node backfill_child_registry.js --project demo-pediatria360 [--apply]
 *
 * Producao (somente com autorizacao do responsavel pelo projeto):
 *   set GOOGLE_APPLICATION_CREDENTIALS=caminho\conta-de-servico.json
 *   node backfill_child_registry.js --project pediatria360-app [--apply]
 *
 * Ids que aparecem sob mais de um usuario NAO sao registrados: ficam no
 * relatorio para decisao manual (pode ser um documento forjado).
 */
const admin = require("firebase-admin");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

const projectId = arg("--project");
const apply = process.argv.includes("--apply");

if (!projectId) {
  console.error("Informe --project <id>.");
  process.exit(1);
}

admin.initializeApp({ projectId });
const db = admin.firestore();

async function main() {
  const snap = await db.collectionGroup("children").get();

  const owners = new Map();
  for (const doc of snap.docs) {
    const parent = doc.ref.parent.parent;
    if (!parent || parent.parent.id !== "users") continue;
    const list = owners.get(doc.id) || [];
    list.push(parent.id);
    owners.set(doc.id, list);
  }

  let created = 0;
  let already = 0;
  const conflicts = [];

  for (const [childId, uids] of owners) {
    const ref = db.doc(`child_registry/${childId}`);
    const existing = await ref.get();
    if (existing.exists) {
      already++;
      const owner = existing.get("ownerUid");
      const others = uids.filter((u) => u !== owner);
      if (others.length) conflicts.push({ childId, registrado: owner, outros: others });
      continue;
    }
    if (uids.length > 1) {
      conflicts.push({ childId, registrado: null, outros: uids });
      continue;
    }
    if (apply) {
      await ref.create({
        ownerUid: uids[0],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    created++;
  }

  console.log(JSON.stringify({
    modo: apply ? "gravado" : "simulacao",
    criancas: owners.size,
    registrosCriados: created,
    jaRegistradas: already,
    conflitos: conflicts,
  }, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
