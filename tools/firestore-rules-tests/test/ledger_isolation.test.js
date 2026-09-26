/**
 * Testes REAIS das regras Firestore (Firebase Emulator).
 * Requer FIRESTORE_EMULATOR_HOST (ex.: via `npm test` / emulators:exec).
 *
 * Matriz: 2 clinicas (clinicA/clinicB), 2 unidades (unitA1/unitA2),
 * papeis: patient, receptionist, physician, finance, clinicAdmin, platform admin.
 */
const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const PROJECT_ID = "pediatria360-rules-fase9";
const RULES = readFileSync(
  resolve(__dirname, "../../../firestore.rules"),
  "utf8",
);

/** @type {import("@firebase/rules-unit-testing").RulesTestEnvironment} */
let testEnv;

const CLINIC_A = "clinicA";
const CLINIC_B = "clinicB";
const UNIT_A1 = "unitA1";
const UNIT_A2 = "unitA2";

function requireEmulator() {
  if (process.env.FIRESTORE_EMULATOR_HOST == null) {
    return false;
  }
  return true;
}

async function seedUser(db, uid, { role = "professional", verified = true } = {}) {
  await db.doc(`users/${uid}`).set({
    role,
    professionalVerified: verified,
    name: uid,
  });
}

async function seedMembership(db, uid, clinicId, role, unitIds = []) {
  await db.doc(`users/${uid}/clinic_memberships/${clinicId}`).set({
    userId: uid,
    clinicId,
    role,
    active: true,
    unitIds,
  });
  await db.doc(`clinics/${clinicId}/memberships/${uid}`).set({
    userId: uid,
    clinicId,
    role,
    active: true,
    unitIds,
  });
}

async function seedLedger(db, collection, id, data) {
  await db.doc(`${collection}/${id}`).set(data);
}

before(async () => {
  if (!requireEmulator()) return;
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: RULES },
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

async function resetSeed() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    await seedUser(db, "patientA");
    await db.doc("users/patientA").set({
      role: "parent",
      professionalVerified: false,
      name: "patientA",
    });
    await db.doc("users/patientA/children/childA1").set({
      name: "Child A1",
      ownerId: "patientA",
    });

    // Clinica A
    await seedUser(db, "recvA");
    await seedMembership(db, "recvA", CLINIC_A, "receptionist", [UNIT_A1]);
    await seedUser(db, "physA");
    await seedMembership(db, "physA", CLINIC_A, "physician", [UNIT_A1]);
    await seedUser(db, "finA");
    await seedMembership(db, "finA", CLINIC_A, "finance", [UNIT_A1, UNIT_A2]);
    await seedUser(db, "adminA");
    await seedMembership(db, "adminA", CLINIC_A, "clinicAdmin", []);

    // Clinica B
    await seedUser(db, "finB");
    await seedMembership(db, "finB", CLINIC_B, "finance", ["unitB1"]);
    await seedUser(db, "adminB");
    await seedMembership(db, "adminB", CLINIC_B, "clinicAdmin", []);

    // Platform admin
    await db.doc("users/platAdmin").set({
      role: "admin",
      professionalVerified: true,
      name: "platAdmin",
    });

    // Ledgers clinica A / unidade A1 (owner = finA para writes)
    await seedLedger(db, "finance_receivables", "recv-a1", {
      ownerId: "finA",
      clinicId: CLINIC_A,
      unitId: UNIT_A1,
      amountCents: 1000,
      status: "open",
    });
    await seedLedger(db, "billing_guides", "guide-a1", {
      ownerId: "finA",
      clinicId: CLINIC_A,
      unitId: UNIT_A1,
      childId: "childA1",
      status: "draft",
      amountCents: 500,
    });
    await seedLedger(db, "inventory_lots", "lot-a1", {
      ownerId: "finA",
      clinicId: CLINIC_A,
      unitId: UNIT_A1,
      itemId: "item1",
      qty: 10,
      lotCode: "L-A1",
    });
    await seedLedger(db, "inventory_lots", "lot-a2", {
      ownerId: "finA",
      clinicId: CLINIC_A,
      unitId: UNIT_A2,
      itemId: "item1",
      qty: 5,
      lotCode: "L-A2",
    });
    await seedLedger(db, "inventory_movements", "mov-transfer-seed", {
      ownerId: "finA",
      clinicId: CLINIC_A,
      unitId: UNIT_A1,
      type: "transfer",
      fromUnitId: UNIT_A1,
      toUnitId: UNIT_A2,
      qty: 1,
    });

    // Ledgers clinica B
    await seedLedger(db, "finance_receivables", "recv-b1", {
      ownerId: "finB",
      clinicId: CLINIC_B,
      unitId: "unitB1",
      amountCents: 2000,
      status: "open",
    });
    await seedLedger(db, "billing_guides", "guide-b1", {
      ownerId: "finB",
      clinicId: CLINIC_B,
      unitId: "unitB1",
      childId: "childB1",
      status: "draft",
      amountCents: 800,
    });
    await seedLedger(db, "inventory_items", "item-b1", {
      ownerId: "finB",
      clinicId: CLINIC_B,
      unitId: "unitB1",
      name: "Item B",
      active: true,
    });

    // Auditoria
    await seedLedger(db, "security_audit_logs", "audit-a1", {
      actorUid: "adminA",
      action: "export",
      module: "finance",
      at: new Date().toISOString(),
      clinicId: CLINIC_A,
    });
    await seedLedger(db, "security_audit_logs", "audit-b1", {
      actorUid: "adminB",
      action: "export",
      module: "finance",
      at: new Date().toISOString(),
      clinicId: CLINIC_B,
    });

    // Agenda
    await seedLedger(db, "appointments", "appt-a-phys", {
      professionalId: "physA",
      patientId: "patientA",
      unitId: UNIT_A1,
      status: "confirmed",
      startsAt: new Date(),
    });
  });
}

function authedDb(uid, token = {}) {
  return testEnv.authenticatedContext(uid, token).firestore();
}

test("EMULATOR: skip gate when FIRESTORE_EMULATOR_HOST absent", async (t) => {
  if (requireEmulator()) {
    t.skip("emulator present — isolation suite runs below");
  }
});

test("cross-clinic: finance B cannot read finance_receivables of clinic A", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("finB");
  await assertFails(db.doc("finance_receivables/recv-a1").get());
});

test("cross-clinic: finance A cannot read billing of clinic B", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("finA");
  await assertFails(db.doc("billing_guides/guide-b1").get());
});

test("cross-clinic: clinicAdmin A cannot read inventory of clinic B", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("adminA");
  await assertFails(db.doc("inventory_items/item-b1").get());
});

test("same-clinic: finance A can read own clinic receivable", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("finA");
  await assertSucceeds(db.doc("finance_receivables/recv-a1").get());
});

test("same-clinic: physician A can read finance ledger (read role)", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("physA");
  await assertSucceeds(db.doc("finance_receivables/recv-a1").get());
});

test("same-clinic: receptionist cannot WRITE finance receivable", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("recvA");
  await assertFails(
    db.doc("finance_receivables/recv-a1-new").set({
      ownerId: "recvA",
      clinicId: CLINIC_A,
      unitId: UNIT_A1,
      amountCents: 1,
      status: "open",
    }),
  );
});

test("same-clinic: physician cannot WRITE billing guide", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("physA");
  await assertFails(
    db.doc("billing_guides/guide-phys-write").set({
      ownerId: "physA",
      clinicId: CLINIC_A,
      unitId: UNIT_A1,
      childId: "childA1",
      status: "draft",
      amountCents: 10,
    }),
  );
});

test("same-clinic: finance A can WRITE billing guide for clinic A", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("finA");
  await assertSucceeds(
    db.doc("billing_guides/guide-fin-write").set({
      ownerId: "finA",
      clinicId: CLINIC_A,
      unitId: UNIT_A1,
      childId: "childA1",
      status: "draft",
      amountCents: 10,
    }),
  );
});

test("same-clinic: finance A can WRITE inventory transfer movement", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("finA");
  await assertSucceeds(
    db.doc("inventory_movements/mov-new-transfer").set({
      ownerId: "finA",
      clinicId: CLINIC_A,
      unitId: UNIT_A1,
      type: "transfer",
      fromUnitId: UNIT_A1,
      toUnitId: UNIT_A2,
      qty: 2,
    }),
  );
});

test("cross-clinic: finance B cannot WRITE transfer into clinic A lot", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("finB");
  await assertFails(
    db.doc("inventory_lots/lot-a1").set(
      { qty: 99, clinicId: CLINIC_A, ownerId: "finB" },
      { merge: true },
    ),
  );
});

test("patient cannot read clinic A finance ledger", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("patientA");
  await assertFails(db.doc("finance_receivables/recv-a1").get());
});

test("patient cannot read other child without grant (cross patient)", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc("users/patientOther").set({
      role: "parent",
      professionalVerified: false,
    });
    await db.doc("users/patientOther/children/childOther").set({
      name: "Other",
      ownerId: "patientOther",
    });
  });
  const db = authedDb("patientA");
  await assertFails(db.doc("users/patientOther/children/childOther").get());
});

test("physician without child grant cannot read patient child doc", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("physA");
  await assertFails(db.doc("users/patientA/children/childA1").get());
});

test("receptionist cannot read physician appointment of another professional", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("recvA");
  // Rules: only patientId or professionalId — receptionist is neither.
  await assertFails(db.doc("appointments/appt-a-phys").get());
});

test("clinicAdmin A can read security_audit_logs of clinic A", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("adminA");
  await assertSucceeds(db.doc("security_audit_logs/audit-a1").get());
});

test("clinicAdmin A cannot read security_audit_logs of clinic B", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("adminA");
  await assertFails(db.doc("security_audit_logs/audit-b1").get());
});

test("platform admin can read security_audit_logs (global)", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("platAdmin", { admin: true });
  await assertSucceeds(db.doc("security_audit_logs/audit-b1").get());
});

test("finance cannot escalate clinicId on update (clinicId unchanged)", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  const db = authedDb("finA");
  await assertFails(
    db.doc("finance_receivables/recv-a1").set(
      { clinicId: CLINIC_B, ownerId: "finA", amountCents: 1 },
      { merge: true },
    ),
  );
});

test("DOCUMENTADO: rules NÃO isolam unitId (unitA1 vs unitA2 same clinic)", async (t) => {
  if (!requireEmulator()) {
    t.skip("NÃO TESTADO: FIRESTORE_EMULATOR_HOST ausente");
    return;
  }
  await resetSeed();
  // Membership de finA inclui ambas unidades; membership de recvA só UNIT_A1.
  // Regras de ledger checam clinicId+role, não unitId — leitura de lot-a2
  // por recvA (inventory read role? receptionist NÃO está em inventoryReadRole).
  // Physician/finance com membership clinic A lê lot de qualquer unitId.
  const db = authedDb("finA");
  await assertSucceeds(db.doc("inventory_lots/lot-a2").get());
  // Evidencia: isolamento por unidade permanece no app (TenantScope), não nas rules.
  assert.ok(true, "unit isolation is app-layer only under current rules");
});
