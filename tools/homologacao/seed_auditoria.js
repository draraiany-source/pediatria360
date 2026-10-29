// Dados fictícios para a auditoria tela por tela, nos emuladores locais
// (projeto demo-pediatria360). Rodar com os emuladores já ligados:
//   node tools/homologacao/seed_auditoria.js
// Senha de todas as contas: Senha-teste-123. Nenhum dado real.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const { initializeApp } = require('firebase/app');
const A = require('firebase/auth');
const FN = require('firebase/functions');
const admin = require('firebase-admin');

const PROJECT = 'demo-pediatria360';
const REGION = 'southamerica-east1';
const SENHA = 'Senha-teste-123';
const CL = 'clinica-auditoria';
admin.initializeApp({ projectId: PROJECT });
const adb = admin.firestore();
const TS = admin.firestore.Timestamp;

async function conta(email, name, extra) {
  let u;
  try { u = await admin.auth().getUserByEmail(email); }
  catch (e) { u = await admin.auth().createUser({ email, password: SENHA, displayName: name, emailVerified: true }); }
  await adb.doc('users/' + u.uid).set(Object.assign({
    email, name, role: 'parent', plan: 'free', emailVerified: true, onboardingDone: true,
    professionalVerified: false, xp: 0, createdAt: TS.now(),
    consentPurposes: { terms: true, privacy: true },
  }, extra || {}), { merge: true });
  return u.uid;
}

async function vinculo(uid, role, nome) {
  const id = 'm-' + uid.slice(0, 10);
  const m = { id, userId: uid, clinicId: CL, clinicName: 'Clínica Fictícia Sol', role, active: true, name: nome, createdAt: new Date().toISOString() };
  await adb.doc('clinics/' + CL + '/memberships/' + id).set(m);
  await adb.doc('users/' + uid + '/clinic_memberships/' + CL).set(m);
}

async function crianca(owner, id, nome, nasc, sexo) {
  await adb.doc('users/' + owner + '/children/' + id).set({
    ownerId: owner, name: nome, birthDate: TS.fromDate(new Date(nasc)), sex: sexo,
    allergies: [], conditions: [], medications: [], updatedAt: TS.now(),
  });
  await adb.doc('child_registry/' + id).set({ ownerUid: owner, createdAt: TS.now() });
}

async function concessao(owner, childId, prof, scopes) {
  await adb.doc('users/' + owner + '/children/' + childId + '/authorized_professionals/' + prof).set({
    source: 'guardian', scopes, clinicId: CL, grantedBy: owner, grantedAt: TS.now(),
    expiresAt: TS.fromMillis(Date.now() + 60 * 864e5), revokedAt: null,
  });
}

async function chamar(email, nome, dados) {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'fake-key', authDomain: 'localhost' }, email);
  const auth = A.getAuth(app);
  A.connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  await A.signInWithEmailAndPassword(auth, email, SENHA);
  const fns = FN.getFunctions(app, REGION);
  FN.connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  return FN.httpsCallable(fns, nome)(dados).then((r) => r.data);
}

// Próximo dia útil + d, às `hora` locais (UTC-3).
function horario(d, hora) {
  const t = new Date(Date.now() + d * 864e5);
  while (t.getUTCDay() === 0 || t.getUTCDay() === 6) t.setUTCDate(t.getUTCDate() + 1);
  t.setUTCHours(hora + 3, 0, 0, 0);
  return t.toISOString();
}

(async () => {
  const ana = await conta('familia.ana@exemplo.invalid', 'Ana Fictícia', { communicationPrefs: { marketingConsent: true, preferredChannel: 'inApp' } });
  const bruno = await conta('familia.bruno@exemplo.invalid', 'Bruno Fictício', { communicationPrefs: { marketingConsent: false, preferredChannel: 'inApp' } });
  const carla = await conta('dra.carla@exemplo.invalid', 'Dra. Carla Fictícia', { role: 'professional', plan: 'pro', professionalVerified: true, crm: '00000-SP', specialty: 'Pediatria geral', consultationMinutes: 30 });
  const diego = await conta('dr.diego@exemplo.invalid', 'Dr. Diego (outra clínica)', { role: 'professional', plan: 'pro', professionalVerified: true, crm: '11111-SP', specialty: 'Pediatria geral' });
  const eva = await conta('recepcao.eva@exemplo.invalid', 'Eva Recepção');
  const fabio = await conta('financeiro.fabio@exemplo.invalid', 'Fábio Financeiro');
  const gina = await conta('gestao.gina@exemplo.invalid', 'Gina Gestão');
  const hugo = await conta('gestao.hugo@exemplo.invalid', 'Hugo Gestão');

  await adb.doc('clinics/' + CL).set({ id: CL, name: 'Clínica Fictícia Sol', tradeName: 'Clínica Sol', active: true, plan: 'basic', ownerUserId: gina, createdAt: new Date().toISOString() });
  await vinculo(carla, 'physician', 'Dra. Carla Fictícia');
  await vinculo(eva, 'receptionist', 'Eva Recepção');
  await vinculo(fabio, 'finance', 'Fábio Financeiro');
  await vinculo(gina, 'clinicAdmin', 'Gina Gestão');
  await vinculo(hugo, 'clinicAdmin', 'Hugo Gestão');

  const dias = {};
  for (let d = 1; d <= 5; d++) dias[String(d)] = ['08:00-18:00'];
  await adb.doc('clinics/' + CL + '/professional_schedules/' + carla).set({ active: true, hours: dias, breaks: { 1: ['12:00-13:00'], 2: ['12:00-13:00'], 3: ['12:00-13:00'], 4: ['12:00-13:00'], 5: ['12:00-13:00'] } });

  await crianca(ana, 'aud-luna', 'Luna Fictícia', '2024-03-10', 'female');
  await crianca(ana, 'aud-theo', 'Theo Fictício', '2021-08-22', 'male');
  await crianca(bruno, 'aud-mia', 'Mia Fictícia', '2023-01-15', 'female');
  await concessao(ana, 'aud-luna', carla, ['summary', 'chart']);
  await concessao(bruno, 'aud-mia', carla, ['summary']);

  const r1 = await chamar('recepcao.eva@exemplo.invalid', 'scheduleAppointment', {
    clinicId: CL, professionalId: carla, childId: 'aud-luna', patientId: ana, startsAt: horario(1, 10), status: 'awaitingConfirmation', reason: 'Consulta de rotina (fictícia)',
  });
  const r2 = await chamar('recepcao.eva@exemplo.invalid', 'scheduleAppointment', {
    clinicId: CL, professionalId: carla, childId: 'aud-mia', patientId: bruno, startsAt: horario(1, 11), status: 'confirmed', reason: 'Retorno (fictício)',
  });
  console.log(JSON.stringify({ ok: true, clinicId: CL, consultas: [r1.appointmentIds, r2.appointmentIds], uids: { ana, bruno, carla, diego, eva, fabio, gina, hugo } }));
  process.exit(0);
})().catch((e) => { console.error('FALHA', e); process.exit(1); });
