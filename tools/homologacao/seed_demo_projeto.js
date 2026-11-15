// Contas e dados FICTÍCIOS de demonstração no projeto Firebase real.
// Uso (credenciais de administrador via Application Default Credentials):
//   set CONFIRMAR_PROJETO=pediatria360-app
//   node tools/homologacao/seed_demo_projeto.js
// As senhas são geradas a cada execução e mostradas só no terminal.
// Nenhum dado real de paciente.
const crypto = require('crypto');
const path = require('path');
const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));

const PROJECT = 'pediatria360-app';
if (process.env.CONFIRMAR_PROJETO !== PROJECT) {
  console.error('Defina CONFIRMAR_PROJETO=' + PROJECT + ' para confirmar o projeto de destino.');
  process.exit(1);
}
if (process.env.FIRESTORE_EMULATOR_HOST || process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.error('Variáveis de emulador definidas; este script é só para o projeto real.');
  process.exit(1);
}

admin.initializeApp({ projectId: PROJECT });
const adb = admin.firestore();
const TS = admin.firestore.Timestamp;
const CL = 'clinica-demo-ficticia';
const CL_NOME = 'Clínica Demonstração (FICTÍCIA)';

function senha() {
  return 'Demo-' + crypto.randomBytes(9).toString('base64url');
}

async function conta(email, name, extra) {
  const pass = senha();
  let u;
  try {
    u = await admin.auth().getUserByEmail(email);
    await admin.auth().updateUser(u.uid, { password: pass, displayName: name, emailVerified: true });
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;
    u = await admin.auth().createUser({ email, password: pass, displayName: name, emailVerified: true });
  }
  await adb.doc('users/' + u.uid).set(Object.assign({
    email, name, role: 'parent', plan: 'free', emailVerified: true, onboardingDone: true,
    professionalVerified: false, xp: 0, demoAccount: true, createdAt: TS.now(),
    consentPurposes: { terms: true, privacy: true },
  }, extra || {}), { merge: true });
  return { uid: u.uid, email, pass };
}

async function vinculo(uid, role, nome) {
  const m = { id: uid, userId: uid, clinicId: CL, clinicName: CL_NOME, role, active: true, name: nome, unitIds: [], createdAt: new Date().toISOString() };
  await adb.doc('clinics/' + CL + '/memberships/' + uid).set(m);
  await adb.doc('users/' + uid + '/clinic_memberships/' + CL).set(m);
}

function proximoDiaUtil(d, hora) {
  const t = new Date(Date.now() + d * 864e5);
  while (t.getUTCDay() === 0 || t.getUTCDay() === 6) t.setUTCDate(t.getUTCDate() + 1);
  t.setUTCHours(hora + 3, 0, 0, 0);
  return t;
}

(async () => {
  const familia = await conta('familia.demo@exemplo.invalid', 'Família Demonstração', {
    communicationPrefs: { marketingConsent: false, preferredChannel: 'inApp' },
  });
  const prof = await conta('profissional.demo@exemplo.invalid', 'Dra. Demonstração (fictícia)', {
    role: 'professional', plan: 'pro', professionalVerified: true, crm: '00000-SP',
    specialty: 'Pediatria geral', consultationMinutes: 30,
  });
  const recep = await conta('recepcao.demo@exemplo.invalid', 'Recepção Demonstração');

  await adb.doc('clinics/' + CL).set({
    id: CL, name: CL_NOME, tradeName: 'Clínica Demo', active: true, plan: 'basic',
    ownerUserId: prof.uid, demo: true, createdAt: new Date().toISOString(),
  }, { merge: true });
  await vinculo(prof.uid, 'physician', 'Dra. Demonstração (fictícia)');
  await vinculo(recep.uid, 'receptionist', 'Recepção Demonstração');

  const dias = {};
  const pausas = {};
  for (let d = 1; d <= 5; d++) { dias[String(d)] = ['08:00-18:00']; pausas[String(d)] = ['12:00-13:00']; }
  await adb.doc('clinics/' + CL + '/professional_schedules/' + prof.uid).set({ active: true, hours: dias, breaks: pausas });

  const childId = 'demo-crianca-1';
  await adb.doc('users/' + familia.uid + '/children/' + childId).set({
    ownerId: familia.uid, name: 'Criança Fictícia', birthDate: TS.fromDate(new Date('2023-06-15')), sex: 'female',
    allergies: [], conditions: [], medications: [], updatedAt: TS.now(),
  });
  await adb.doc('child_registry/' + childId).set({ ownerUid: familia.uid, createdAt: TS.now() });
  await adb.doc('users/' + familia.uid + '/children/' + childId + '/authorized_professionals/' + prof.uid).set({
    source: 'guardian', scopes: ['summary', 'chart'], clinicId: CL, grantedBy: familia.uid, grantedAt: TS.now(),
    expiresAt: TS.fromMillis(Date.now() + 60 * 864e5), revokedAt: null,
  });

  const inicio = proximoDiaUtil(1, 10);
  await adb.doc('appointments/demo-consulta-1').set({
    patientId: familia.uid, professionalId: prof.uid, professionalName: 'Dra. Demonstração (fictícia)',
    specialty: 'Pediatria geral', startsAt: TS.fromDate(inicio), durationMinutes: 30, type: 'inPerson',
    status: 'confirmed', origin: 'clinicStaff', childId, childName: 'Criança Fictícia',
    reason: 'Consulta de rotina (fictícia)', clinicId: CL, unitId: null, priceCents: 0, paid: false,
    scheduleVersion: 1, rescheduleCount: 0, lockIds: [], remindersManaged: false, seriesId: null,
    workflowStatus: 'scheduled', createdBy: recep.uid, demo: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(), updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('Contas de demonstração (senhas válidas até a próxima execução):');
  for (const [perfil, c] of [['Família', familia], ['Profissional', prof], ['Recepção', recep]]) {
    console.log(perfil + '\t' + c.email + '\t' + c.pass);
  }
  process.exit(0);
})().catch((e) => { console.error('FALHA', e.message || e); process.exit(1); });
