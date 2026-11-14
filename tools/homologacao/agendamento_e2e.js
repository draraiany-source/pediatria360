// Conferência ponta a ponta do agendamento pela recepção e pela família, nos
// emuladores (projeto demo-pediatria360), com os mesmos dados que as telas
// `ClinicBookingScreen` e `FamilyBookingScreen` enviam. Rodar depois do
// seed_auditoria.js:
//   node tools/homologacao/agendamento_e2e.js
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const { initializeApp } = require('firebase/app');
const A = require('firebase/auth');
const FN = require('firebase/functions');
const F = require('firebase/firestore');

const PROJECT = 'demo-pediatria360';
const REGION = 'southamerica-east1';
const SENHA = 'Senha-teste-123';
const CL = 'clinica-auditoria';
const resultados = [];

async function sessao(email) {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'fake-key', authDomain: 'localhost' }, email);
  const auth = A.getAuth(app);
  A.connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const cred = await A.signInWithEmailAndPassword(auth, email, SENHA);
  const fns = FN.getFunctions(app, REGION);
  FN.connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  const db = F.getFirestore(app);
  const [fsHost, fsPort] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  F.connectFirestoreEmulator(db, fsHost, Number(fsPort));
  return { uid: cred.user.uid, call: (n, d) => FN.httpsCallable(fns, n)(d).then((r) => r.data), db };
}

async function caso(nome, esperado, fn) {
  try {
    const obs = await fn();
    const ok = esperado === 'ok';
    resultados.push({ nome, esperado, observado: 'ok ' + JSON.stringify(obs).slice(0, 120), passou: ok });
  } catch (e) {
    const ok = esperado !== 'ok' && String(e.code || '').includes(esperado);
    resultados.push({ nome, esperado, observado: `${e.code}: ${e.message}`, passou: ok });
  }
}

(async () => {
  const eva = await sessao('recepcao.eva@exemplo.invalid');
  const ana = await sessao('familia.ana@exemplo.invalid');
  const bruno = await sessao('familia.bruno@exemplo.invalid');
  const membros = await F.getDocs(F.query(F.collection(eva.db, 'clinics', CL, 'memberships'), F.where('active', '==', true)));
  const carla = membros.docs.map((d) => d.data()).find((m) => m.role === 'physician').userId;

  const hoje = new Date(); hoje.setHours(0, 0, 0, 0);
  const slots = await eva.call('getScheduleSlots', { clinicId: CL, professionalId: carla, from: hoje.toISOString(), days: 14, appointmentType: 'presencial' });
  const livres = slots.slots;
  resultados.push({ nome: 'Recepção: horários livres reais (14 dias)', esperado: '>0', observado: String(livres.length), passou: livres.length > 0 });

  const contatos = await F.getDocs(F.collection(eva.db, 'clinics', CL, 'crm_contacts'));
  resultados.push({ nome: 'Recepção: lista de pacientes pelo CRM', esperado: '>0', observado: String(contatos.size), passou: contatos.size > 0 });

  const pedido = (start, childId, patientId) => ({
    clinicId: CL, patientId, childId, professionalId: carla, startsAt: start,
    appointmentType: 'presencial', status: 'confirmed', reason: 'Retorno (fictício)',
  });
  await caso('Recepção agenda criança autorizada (Luna)', 'ok', () => eva.call('scheduleAppointment', pedido(livres[0], 'aud-luna', ana.uid)));
  await caso('Recepção repete o mesmo horário (conflito)', 'already-exists', () => eva.call('scheduleAppointment', pedido(livres[0], 'aud-luna', ana.uid)));
  await caso('Recepção agenda criança sem autorização (Theo)', 'permission-denied', () => eva.call('scheduleAppointment', pedido(livres[1], 'aud-theo', ana.uid)));
  await caso('Recepção com responsável trocado', 'permission-denied', () => eva.call('scheduleAppointment', pedido(livres[1], 'aud-luna', bruno.uid)));

  const slotsFam = await ana.call('getScheduleSlots', { clinicId: CL, professionalId: carla, from: hoje.toISOString(), days: 14, appointmentType: 'presencial' });
  const livreFam = slotsFam.slots.find((s) => s !== livres[0]);
  await caso('Família pede horário para a própria criança', 'ok', () => ana.call('bookAppointment', {
    professionalId: carla, startsAt: livreFam, childId: 'aud-luna', reason: 'Rotina (fictício)', clinicId: CL, appointmentType: 'presencial',
  }));
  await caso('Família pede horário para criança de outra família', 'permission-denied', () => ana.call('bookAppointment', {
    professionalId: carla, startsAt: slotsFam.slots[2], childId: 'aud-mia', clinicId: CL, appointmentType: 'presencial',
  }));
  await caso('Família pede o horário já ocupado', 'already-exists', () => ana.call('bookAppointment', {
    professionalId: carla, startsAt: livres[0], childId: 'aud-luna', clinicId: CL, appointmentType: 'presencial',
  }));

  const minhas = await F.getDocs(F.query(F.collection(ana.db, 'appointments'), F.where('patientId', '==', ana.uid)));
  const pedidoFam = minhas.docs.map((d) => d.data()).find((a) => a.origin === 'familyBooking');
  resultados.push({
    nome: 'Família vê o pedido em "Suas consultas" com status da política',
    esperado: 'requested', observado: pedidoFam ? `${pedidoFam.status} / ${pedidoFam.type}` : 'ausente',
    passou: !!pedidoFam && pedidoFam.status === 'requested' && pedidoFam.type === 'presencial',
  });

  for (const r of resultados) console.log(`${r.passou ? 'PASSOU' : 'FALHOU'} | ${r.nome} | esperado: ${r.esperado} | observado: ${r.observado}`);
  const falhas = resultados.filter((r) => !r.passou).length;
  console.log(`\n${resultados.length - falhas}/${resultados.length} conforme o esperado`);
  process.exit(falhas ? 1 : 0);
})().catch((e) => { console.error('FALHA', e); process.exit(1); });
