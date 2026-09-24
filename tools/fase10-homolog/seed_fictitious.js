/**
 * FASE 10 — seed de dados FICTICIOS no Firebase Emulator (Auth + Firestore).
 * Nao usa pacientes reais. Requer:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
 *   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
 */
const admin = require("firebase-admin");

const PROJECT = process.env.GCLOUD_PROJECT || "pediatria360-app";

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error("FIRESTORE_EMULATOR_HOST ausente — abortando (nao seed em producao).");
  process.exit(1);
}
if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error("FIREBASE_AUTH_EMULATOR_HOST ausente — abortando.");
  process.exit(1);
}

admin.initializeApp({ projectId: PROJECT });
const auth = admin.auth();
const db = admin.firestore();

const PASSWORD = "HomologF10!2026";

const USERS = [
  { uid: "homolog-admin-a", email: "admin.a@homolog.pediatria360.test", name: "Admin Homolog A", role: "professional", verified: true, clinic: "clinicHomologA", clinicRole: "clinicAdmin", units: [] },
  { uid: "homolog-recv-a", email: "recepcao.a@homolog.pediatria360.test", name: "Recepcao Homolog A", role: "professional", verified: true, clinic: "clinicHomologA", clinicRole: "receptionist", units: ["unitCentro"] },
  { uid: "homolog-phys-a", email: "medico.a@homolog.pediatria360.test", name: "Medico Homolog A", role: "professional", verified: true, clinic: "clinicHomologA", clinicRole: "physician", units: ["unitCentro"] },
  { uid: "homolog-fin-a", email: "financeiro.a@homolog.pediatria360.test", name: "Financeiro Homolog A", role: "professional", verified: true, clinic: "clinicHomologA", clinicRole: "finance", units: ["unitCentro", "unitNorte"] },
  { uid: "homolog-admin-b", email: "admin.b@homolog.pediatria360.test", name: "Admin Homolog B", role: "professional", verified: true, clinic: "clinicHomologB", clinicRole: "clinicAdmin", units: [] },
  { uid: "homolog-parent-a", email: "responsavel.a@homolog.pediatria360.test", name: "Responsavel Homolog A", role: "parent", verified: false, clinic: null, clinicRole: null, units: [] },
  { uid: "homolog-parent-b", email: "responsavel.b@homolog.pediatria360.test", name: "Responsavel Homolog B", role: "parent", verified: false, clinic: null, clinicRole: null, units: [] },
];

async function upsertAuthUser(u) {
  try {
    await auth.getUser(u.uid);
    await auth.updateUser(u.uid, { email: u.email, password: PASSWORD, displayName: u.name, emailVerified: true });
  } catch (e) {
    if (e.code === "auth/user-not-found") {
      await auth.createUser({ uid: u.uid, email: u.email, password: PASSWORD, displayName: u.name, emailVerified: true });
    } else throw e;
  }
}

async function main() {
  console.log("Seeding FASE 10 fictional data into emulator…");
  for (const u of USERS) {
    await upsertAuthUser(u);
    await db.doc(`users/${u.uid}`).set({
      uid: u.uid,
      email: u.email,
      name: u.name,
      role: u.role,
      professionalVerified: u.verified,
      plan: "pro",
      onboardingCompleted: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    if (u.clinic) {
      await db.doc(`users/${u.uid}/clinic_memberships/${u.clinic}`).set({
        userId: u.uid,
        clinicId: u.clinic,
        role: u.clinicRole,
        active: true,
        unitIds: u.units,
      }, { merge: true });
    }
  }

  await db.doc("clinics/clinicHomologA").set({
    name: "Clinica Homolog A (FICTICIA)",
    active: true,
  }, { merge: true });
  await db.doc("clinics/clinicHomologA/units/unitCentro").set({ name: "Unidade Centro", active: true }, { merge: true });
  await db.doc("clinics/clinicHomologA/units/unitNorte").set({ name: "Unidade Norte", active: true }, { merge: true });
  await db.doc("clinics/clinicHomologB").set({
    name: "Clinica Homolog B (FICTICIA)",
    active: true,
  }, { merge: true });
  await db.doc("clinics/clinicHomologB/units/unitB1").set({ name: "Unidade B1", active: true }, { merge: true });

  // Membership espelho na clinica
  for (const u of USERS.filter((x) => x.clinic)) {
    await db.doc(`clinics/${u.clinic}/memberships/${u.uid}`).set({
      userId: u.uid,
      role: u.clinicRole,
      active: true,
      unitIds: u.units,
    }, { merge: true });
  }

  // Crianca ficticia da familia A
  await db.doc("users/homolog-parent-a/children/child-ficticio-a1").set({
    name: "Crianca Ficticia A1",
    birthDate: "2020-05-10",
    ownerId: "homolog-parent-a",
    sex: "F",
  }, { merge: true });

  // Crianca ficticia familia B (para teste negativo)
  await db.doc("users/homolog-parent-b/children/child-ficticio-b1").set({
    name: "Crianca Ficticia B1",
    birthDate: "2019-01-01",
    ownerId: "homolog-parent-b",
    sex: "M",
  }, { merge: true });

  // Agendamento ficticio medico A
  const starts = new Date();
  starts.setHours(starts.getHours() + 2, 0, 0, 0);
  await db.doc("appointments/appt-homolog-a1").set({
    professionalId: "homolog-phys-a",
    patientId: "homolog-parent-a",
    childId: "child-ficticio-a1",
    unitId: "unitCentro",
    clinicId: "clinicHomologA",
    status: "confirmed",
    workflowStatus: "confirmed",
    startsAt: admin.firestore.Timestamp.fromDate(starts),
    endsAt: admin.firestore.Timestamp.fromDate(new Date(starts.getTime() + 30 * 60000)),
    type: "inPerson",
  }, { merge: true });

  // Recebivel ficticio
  await db.doc("finance_receivables/recv-homolog-a1").set({
    ownerId: "homolog-fin-a",
    clinicId: "clinicHomologA",
    unitId: "unitCentro",
    amountCents: 25000,
    status: "open",
    description: "Consulta ficticia Homolog F10",
    dueAt: admin.firestore.Timestamp.fromDate(new Date()),
  }, { merge: true });

  // Consentimento ficticio
  await db.doc("users/homolog-parent-a/consents/consent-homolog-1").set({
    type: "privacy",
    grantedAt: admin.firestore.Timestamp.fromDate(new Date()),
    granted: true,
  }, { merge: true });

  console.log("OK seed. Password for all users:", PASSWORD);
  console.log(USERS.map((u) => `${u.clinicRole || u.role}\t${u.email}`).join("\n"));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});