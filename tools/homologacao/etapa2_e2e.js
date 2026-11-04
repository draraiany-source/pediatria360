// Etapa 2 (25/10/2026): fluxo da clinica com autorizacao explicita, contra os
// emuladores locais (projeto demo-pediatria360). Dados ficticios.
// Saida: etapa2_e2e.json ao lado deste arquivo.
const fs = require('fs');
const { initializeApp } = require('firebase/app');
const A = require('firebase/auth');
const F = require('firebase/firestore');
const FN = require('firebase/functions');
const admin = require('firebase-admin');

const PROJECT = 'demo-pediatria360';
const REGION = 'southamerica-east1';
admin.initializeApp({ projectId: PROJECT });
const adb = admin.firestore();
const TS = admin.firestore.Timestamp;

const results = [];
// expected: 'permitido', 'nao-permitido' (qualquer recusa) ou o codigo exato
// (ex.: 'permission-denied', 'not-found').
function rec(area, name, expected, o) {
  const observed = typeof o === 'string' ? o : o.r;
  const ok = expected === 'nao-permitido' ? observed !== 'permitido' : expected === observed;
  const note = (o && o.e) || '';
  results.push({ area, name, expected, observed, ok, note });
  console.log((ok ? 'OK    ' : 'DIVERG') + ' [' + area + '] ' + name + ' | esperado=' + expected + ' observado=' + observed + (note ? ' | ' + note : ''));
}
async function outcome(fn) {
  try { const v = await fn(); return { r: 'permitido', v }; }
  catch (e) {
    const code = String((e && e.code) || 'erro').replace(/^(functions|firestore)\//, '');
    return { r: code, e: code + ': ' + ((e && e.message) || String(e)) };
  }
}
const sim = (b) => (b ? 'sim' : 'nao');

let appN = 0;
async function client(email) {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'fake-key', authDomain: 'localhost' }, 'e' + (appN++));
  const auth = A.getAuth(app);
  A.connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const db = F.getFirestore(app);
  F.connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const fns = FN.getFunctions(app, REGION);
  FN.connectFunctionsEmulator(fns, '127.0.0.1', 5001);
  let cred;
  try { cred = await A.createUserWithEmailAndPassword(auth, email, 'Senha-teste-123'); }
  catch (e) { cred = await A.signInWithEmailAndPassword(auth, email, 'Senha-teste-123'); }
  return {
    db, email, uid: cred.user.uid,
    call: (name, data) => FN.httpsCallable(fns, name)(data).then((r) => r.data),
    verifyEmail: async () => {
      await admin.auth().updateUser(cred.user.uid, { emailVerified: true });
      await auth.currentUser.reload();
      await auth.currentUser.getIdToken(true);
    },
  };
}

async function membership(clinicId, c, role) {
  const id = 'm-' + c.uid.slice(0, 8);
  const m = { id, userId: c.uid, clinicId, role, active: true, name: '' };
  await adb.doc('clinics/' + clinicId + '/memberships/' + id).set(m);
  await adb.doc('users/' + c.uid + '/clinic_memberships/' + clinicId).set(m);
}

(async () => {
  const famA = await client('familia.a@exemplo.invalid');
  const famB = await client('familia.b@exemplo.invalid');
  const ped = await client('pediatra@exemplo.invalid');
  const ped2 = await client('pediatra2@exemplo.invalid');
  const inv = await client('invasor@exemplo.invalid');
  const recp = await client('recepcao@exemplo.invalid');
  const fin = await client('financeiro@exemplo.invalid');
  const gest = await client('gestao@exemplo.invalid');
  const fin2 = await client('financeiro2@exemplo.invalid');

  const conta = (name) => ({ name, role: 'parent', plan: 'free', professionalVerified: false, xp: 0 });
  for (const [c, n] of [[famA, 'Responsavel A'], [famB, 'Responsavel B'], [recp, 'Recepcao Exemplo'],
    [fin, 'Financeiro Exemplo'], [gest, 'Gestao Exemplo'], [fin2, 'Financeiro Dois']]) {
    await adb.doc('users/' + c.uid).set(conta(n));
  }
  for (const [c, n] of [[ped, 'Dra. Exemplo'], [ped2, 'Dr. Segundo'], [inv, 'Invasor Exemplo']]) {
    await adb.doc('users/' + c.uid).set({ name: n, role: 'professional', plan: 'pro', professionalVerified: true, xp: 0, consultationMinutes: 30, specialty: 'Pediatria' });
  }

  const CL = 'clinica-e2e';
  await adb.doc('clinics/' + CL).set({ name: 'Clinica Exemplo', ownerUserId: gest.uid });
  await membership(CL, gest, 'clinicAdmin');
  await membership(CL, ped, 'physician');
  await membership(CL, recp, 'receptionist');
  await membership(CL, fin, 'finance');

  // Criancas ja cadastradas pelas familias (lote crianca + child_registry).
  async function crianca(c, id, nome) {
    const b = F.writeBatch(c.db);
    b.set(F.doc(c.db, 'users', c.uid, 'children', id), { name: nome, createdAt: F.serverTimestamp() });
    b.set(F.doc(c.db, 'child_registry', id), { ownerUid: c.uid, createdAt: F.serverTimestamp() });
    await b.commit();
  }
  await crianca(famA, 'crianca-a', 'Luna Exemplo');
  await crianca(famB, 'crianca-b', 'Theo Exemplo');
  const childRef = (c, owner, id) => F.doc(c.db, 'users', owner.uid, 'children', id);

  const dia = (d, h) => {
    const t = new Date(Date.now() + d * 864e5);
    t.setUTCHours(h, 0, 0, 0);
    return t.toISOString();
  };
  const pedido = (extra) => ({
    clinicId: CL, professionalId: ped.uid, childName: 'Luna Exemplo', childBirthDate: '2025-01-10',
    guardianName: 'Responsavel A', guardianEmail: famA.email, guardianPhone: '', startsAt: dia(3, 13),
    durationMinutes: 30, reason: 'Primeira consulta (ficticia)', ...extra,
  });

  // ------------------------------------------------------- Equipe da clinica
  rec('equipe', 'recepcao NAO adiciona membro', 'permission-denied',
    await outcome(() => recp.call('addClinicMember', { clinicId: CL, email: ped2.email, role: 'physician' })));
  const am = await outcome(() => gest.call('addClinicMember', { clinicId: CL, email: ped2.email, role: 'physician' }));
  rec('equipe', 'gestao adiciona medico verificado', 'permitido', am);
  const m2 = (await adb.doc('users/' + ped2.uid + '/clinic_memberships/' + CL).get()).data() || {};
  rec('equipe', 'vinculo gravado nas duas pontas, com nome', 'sim', sim(m2.active === true && m2.role === 'physician' && m2.name === 'Dr. Segundo' &&
    (await adb.doc('clinics/' + CL + '/memberships/' + m2.id).get()).exists));
  rec('equipe', 'gestao NAO da papel clinico a conta comum', 'failed-precondition',
    await outcome(() => gest.call('addClinicMember', { clinicId: CL, email: famA.email, role: 'physician' })));
  rec('equipe', 'gestao adiciona financeiro (conta comum)', 'permitido',
    await outcome(() => gest.call('addClinicMember', { clinicId: CL, email: fin2.email, role: 'finance' })));
  const mg = (await adb.doc('users/' + gest.uid + '/clinic_memberships/' + CL).get()).data();
  rec('equipe', 'gestao NAO deixa a clinica sem gestor ativo', 'failed-precondition',
    await outcome(() => gest.call('setClinicMemberStatus', { clinicId: CL, membershipId: mg.id, active: false })));

  // ---------------------------------------------------- Paciente novo (intake)
  const c1 = await outcome(() => recp.call('createClinicIntake', pedido()));
  rec('solicitacao', 'recepcao (conta comum) registra paciente novo', 'permitido', c1);
  const code1 = c1.v && c1.v.inviteCode;
  const intake1 = c1.v && c1.v.intakeId;
  rec('solicitacao', 'financeiro NAO registra solicitacao', 'permission-denied',
    await outcome(() => fin.call('createClinicIntake', pedido({ childName: 'Outra Crianca', startsAt: dia(3, 14) }))));
  rec('solicitacao', 'profissional de fora NAO registra na clinica', 'permission-denied',
    await outcome(() => inv.call('createClinicIntake', pedido({ professionalId: inv.uid, startsAt: dia(3, 15) }))));
  rec('solicitacao', 'duplicada (mesma crianca e responsavel) recusada', 'already-exists',
    await outcome(() => recp.call('createClinicIntake', pedido({ startsAt: dia(4, 13) }))));
  rec('solicitacao', 'mesmo horario do profissional recusado', 'already-exists',
    await outcome(() => recp.call('createClinicIntake', pedido({ childName: 'Crianca Dois', guardianEmail: famB.email }))));

  const i1 = intake1 ? (await adb.doc('clinic_intakes/' + intake1).get()).data() : {};
  const priv = intake1 ? (await adb.doc('clinic_intakes/' + intake1 + '/private/invite').get()).data() || {} : {};
  rec('solicitacao', 'registro provisorio sem crianca, sem consulta e sem codigo legivel', 'sim',
    sim(i1 && i1.status === 'pendingGuardian' && i1.linkedChildId == null && i1.appointmentId == null &&
      !JSON.stringify(i1).includes(String(code1).replace('-', '')) && !JSON.stringify(priv).includes(String(code1).replace('-', ''))));
  rec('solicitacao', 'recepcao le a solicitacao', 'permitido', await outcome(() => F.getDoc(F.doc(recp.db, 'clinic_intakes', intake1))));
  rec('solicitacao', 'financeiro NAO le a solicitacao', 'permission-denied', await outcome(() => F.getDoc(F.doc(fin.db, 'clinic_intakes', intake1))));
  rec('solicitacao', 'familia NAO le a solicitacao direto', 'permission-denied', await outcome(() => F.getDoc(F.doc(famA.db, 'clinic_intakes', intake1))));

  // Horario reservado pela solicitacao nao vai para outra familia.
  rec('solicitacao', 'familia NAO reserva pelo app horario retido por solicitacao', 'nao-permitido',
    await outcome(() => famB.call('bookAppointment', { professionalId: ped.uid, startsAt: dia(3, 13), childId: 'crianca-b' })));

  // ------------------------------------------------------ Convite e aceite
  rec('convite', 'previa com e-mail ainda nao confirmado', 'failed-precondition',
    await outcome(() => famA.call('previewClinicIntake', { code: code1 })));
  await famA.verifyEmail();
  await famB.verifyEmail();
  rec('convite', 'outra familia (outro e-mail) NAO usa o codigo', 'permission-denied',
    await outcome(() => famB.call('previewClinicIntake', { code: code1 })));
  rec('convite', 'codigo errado', 'not-found', await outcome(() => famA.call('previewClinicIntake', { code: 'AAAAA-BBBBB' })));
  const pv = await outcome(() => famA.call('previewClinicIntake', { code: code1 }));
  rec('convite', 'responsavel ve a previa', 'permitido', pv);
  rec('convite', 'previa mostra clinica, profissional e crianca', 'sim',
    sim(pv.v && pv.v.clinicName === 'Clinica Exemplo' && pv.v.professionalName === 'Dra. Exemplo' && pv.v.childName === 'Luna Exemplo'));

  rec('convite', 'aceite com a crianca de outra familia (id conhecido)', 'permission-denied',
    await outcome(() => famA.call('acceptClinicIntake', { code: code1, childId: 'crianca-b', scopes: ['summary', 'chartWrite'], days: 30 })));
  rec('convite', 'aceite com crianca inexistente', 'permission-denied',
    await outcome(() => famA.call('acceptClinicIntake', { code: code1, childId: 'nao-existe', scopes: ['summary'], days: 30 })));
  rec('convite', 'escopo invalido (prontuario sem resumo)', 'invalid-argument',
    await outcome(() => famA.call('acceptClinicIntake', { code: code1, childId: 'crianca-a', scopes: ['chartWrite'], days: 30 })));
  rec('convite', 'validade acima do limite', 'invalid-argument',
    await outcome(() => famA.call('acceptClinicIntake', { code: code1, childId: 'crianca-a', scopes: ['summary'], days: 900 })));

  rec('autorizado', 'antes do aceite: profissional NAO le a crianca', 'permission-denied', await outcome(() => F.getDoc(childRef(ped, famA, 'crianca-a'))));
  const ac = await outcome(() => famA.call('acceptClinicIntake', { code: code1, childId: 'crianca-a', scopes: ['summary', 'chartWrite'], days: 30 }));
  rec('convite', 'responsavel aceita e autoriza prontuario por 30 dias', 'permitido', ac);
  rec('convite', 'codigo NAO pode ser reutilizado', 'not-found',
    await outcome(() => famA.call('acceptClinicIntake', { code: code1, childId: 'crianca-a', scopes: ['summary'], days: 30 })));

  const apptQ = await adb.collection('appointments').where('intakeId', '==', intake1).get();
  const appt = apptQ.empty ? {} : apptQ.docs[0].data();
  const apptId = apptQ.empty ? null : apptQ.docs[0].id;
  rec('convite', 'consulta criada pelo servidor, origem clinicIntake, titular e crianca certos', 'sim',
    sim(appt.origin === 'clinicIntake' && appt.patientId === famA.uid && appt.childId === 'crianca-a' && appt.clinicId === CL && appt.professionalId === ped.uid));
  const g = (await adb.doc('users/' + famA.uid + '/children/crianca-a/authorized_professionals/' + ped.uid).get()).data() || {};
  rec('convite', 'concessao guardianInvite, autor = titular, validade ~30 dias', 'sim',
    sim(g.source === 'guardianInvite' && g.authorizedBy === famA.uid && g.revokedAt === null &&
      Math.abs(g.expiresAt.toMillis() - Date.now() - 30 * 864e5) < 864e5 && g.scopes.includes('chartWrite')));
  const i1b = (await adb.doc('clinic_intakes/' + intake1).get()).data() || {};
  rec('convite', 'solicitacao marcada como vinculada', 'sim', sim(i1b.status === 'linked' && i1b.appointmentId === apptId));

  // ------------------------------------------------------- Atendimento
  rec('autorizado', 'profissional le cadastro', 'permitido', await outcome(() => F.getDoc(childRef(ped, famA, 'crianca-a'))));
  const ca = await outcome(() => ped.call('checkChildAccess', { childId: 'crianca-a', clinicId: CL }));
  rec('autorizado', 'checkChildAccess informa prontuario liberado', 'sim', sim(ca.v && ca.v.chartWrite === true && ca.v.state === 'active'));
  rec('autorizado', 'profissional abre atendimento na clinica', 'permitido',
    await outcome(() => F.setDoc(F.doc(ped.db, 'encounters', 'enc-a'), { patientId: 'crianca-a', professionalId: ped.uid, clinicId: CL, status: 'draft', appointmentId: apptId })));
  rec('perfis', 'recepcao NAO le a crianca', 'permission-denied', await outcome(() => F.getDoc(childRef(recp, famA, 'crianca-a'))));
  rec('perfis', 'gestao NAO le a crianca', 'permission-denied', await outcome(() => F.getDoc(childRef(gest, famA, 'crianca-a'))));
  rec('perfis', 'gestao NAO le o atendimento', 'permission-denied', await outcome(() => F.getDoc(F.doc(gest.db, 'encounters', 'enc-a'))));
  rec('perfis', 'recepcao faz check-in da consulta', 'permitido',
    await outcome(() => F.updateDoc(F.doc(recp.db, 'appointments', apptId), { workflowStatus: 'arrived', arrivedAt: F.serverTimestamp() })));
  rec('perfis', 'recepcao NAO marca pago', 'permission-denied', await outcome(() => F.updateDoc(F.doc(recp.db, 'appointments', apptId), { paid: true })));
  rec('perfis', 'financeiro (conta comum) marca pago', 'permitido', await outcome(() => F.updateDoc(F.doc(fin.db, 'appointments', apptId), { paid: true })));
  rec('perfis', 'financeiro lanca conta a receber da clinica', 'permitido',
    await outcome(() => F.setDoc(F.doc(fin.db, 'finance_receivables', 'rcv-1'), { ownerId: fin.uid, clinicId: CL, amountCents: 20000, appointmentId: apptId })));
  rec('perfis', 'financeiro NAO troca a crianca da consulta', 'permission-denied',
    await outcome(() => F.updateDoc(F.doc(fin.db, 'appointments', apptId), { childId: 'crianca-b' })));

  // ---------------------------------------------- Aceite sem acesso clinico
  const c3 = await outcome(() => recp.call('createClinicIntake', pedido({ professionalId: ped2.uid, childName: 'Luna Exemplo', startsAt: dia(5, 13) })));
  rec('sem-acesso', 'solicitacao com o segundo medico', 'permitido', c3);
  rec('sem-acesso', 'responsavel aceita a consulta sem conceder acesso', 'permitido',
    await outcome(() => famA.call('acceptClinicIntake', { code: c3.v && c3.v.inviteCode, childId: 'crianca-a', scopes: [], days: 0 })));
  rec('sem-acesso', 'nenhuma concessao gravada para o segundo medico', 'sim',
    sim(!(await adb.doc('users/' + famA.uid + '/children/crianca-a/authorized_professionals/' + ped2.uid).get()).exists));
  rec('sem-acesso', 'consulta existe, mas medico NAO le a crianca', 'permission-denied', await outcome(() => F.getDoc(childRef(ped2, famA, 'crianca-a'))));
  rec('sem-acesso', 'medico NAO abre atendimento so por ter consulta', 'permission-denied',
    await outcome(() => F.setDoc(F.doc(ped2.db, 'encounters', 'enc-ped2'), { patientId: 'crianca-a', professionalId: ped2.uid, clinicId: CL, status: 'draft' })));
  rec('sem-acesso', 'funcao antiga de concessao por consulta nao existe mais', 'nao-permitido',
    await outcome(() => ped2.call('grantChildSummaryAccess', { childId: 'crianca-a' })));

  // ----------------------------------------------------- Somente resumo
  const c2 = await outcome(() => recp.call('createClinicIntake', pedido({ childName: 'Theo Exemplo', guardianName: 'Responsavel B', guardianEmail: famB.email, startsAt: dia(6, 13) })));
  rec('resumo', 'solicitacao para a familia B', 'permitido', c2);
  rec('resumo', 'familia B aceita com somente resumo', 'permitido',
    await outcome(() => famB.call('acceptClinicIntake', { code: c2.v && c2.v.inviteCode, childId: 'crianca-b', scopes: ['summary'], days: 30 })));
  rec('resumo', 'profissional le o cadastro', 'permitido', await outcome(() => F.getDoc(childRef(ped, famB, 'crianca-b'))));
  rec('resumo', 'profissional NAO abre atendimento', 'permission-denied',
    await outcome(() => F.setDoc(F.doc(ped.db, 'encounters', 'enc-b'), { patientId: 'crianca-b', professionalId: ped.uid, clinicId: CL, status: 'draft' })));
  const cb = await outcome(() => ped.call('checkChildAccess', { childId: 'crianca-b', clinicId: CL }));
  rec('resumo', 'checkChildAccess: resumo sim, prontuario nao', 'sim', sim(cb.v && cb.v.summary === true && cb.v.chartWrite === false));
  // Atendimento antigo do profissional para esta crianca (gravado direto, simula legado).
  await adb.doc('encounters/enc-b-legado').set({ patientId: 'crianca-b', professionalId: ped.uid, clinicId: CL, status: 'draft' });
  await adb.doc('encounters/enc-b-assinado').set({ patientId: 'crianca-b', professionalId: ped.uid, clinicId: CL, status: 'signed', signedAt: TS.now() });
  rec('resumo', 'IA clinica NAO roda sem prontuario liberado', 'permission-denied',
    await outcome(() => ped.call('clinicalAssist', { task: 'summarizeEncounter', encounterId: 'enc-b-legado' })));
  rec('resumo', 'assinatura NAO roda sem prontuario liberado', 'permission-denied',
    await outcome(() => ped.call('signEncounter', { encounterId: 'enc-b-legado' })));
  rec('resumo', 'documento clinico NAO e emitido', 'permission-denied',
    await outcome(() => ped.call('issueClinicalDocument', { encounterId: 'enc-b-assinado', type: 'certificate', content: 'Atestado ficticio para teste' })));
  rec('resumo', 'consulta por voz NAO inicia', 'permission-denied',
    await outcome(() => ped.call('startVoiceConsultation', { childId: 'crianca-b', clinicId: CL })));

  // --------------------------------------------------- Cancelar e renovar
  const c4 = await outcome(() => recp.call('createClinicIntake', pedido({ childName: 'Nina Exemplo', guardianName: 'Responsavel B', guardianEmail: famB.email, startsAt: dia(7, 13) })));
  rec('renovar', 'nova solicitacao', 'permitido', c4);
  const rn = await outcome(() => recp.call('renewClinicIntakeCode', { intakeId: c4.v && c4.v.intakeId }));
  rec('renovar', 'recepcao gera novo codigo', 'permitido', rn);
  rec('renovar', 'codigo antigo deixa de valer', 'not-found', await outcome(() => famB.call('previewClinicIntake', { code: c4.v && c4.v.inviteCode })));
  rec('renovar', 'codigo novo vale', 'permitido', await outcome(() => famB.call('previewClinicIntake', { code: rn.v && rn.v.inviteCode })));
  rec('renovar', 'financeiro NAO cancela', 'permission-denied', await outcome(() => fin.call('cancelClinicIntake', { intakeId: c4.v && c4.v.intakeId })));
  rec('renovar', 'recepcao cancela', 'permitido', await outcome(() => recp.call('cancelClinicIntake', { intakeId: c4.v && c4.v.intakeId, reason: 'teste' })));
  rec('renovar', 'apos cancelar, codigo nao vale', 'not-found', await outcome(() => famB.call('previewClinicIntake', { code: rn.v && rn.v.inviteCode })));

  // --------------------------------------------------------- Revogacao
  rec('revogacao', 'responsavel revoga o acesso do medico', 'permitido',
    await outcome(() => F.updateDoc(F.doc(famA.db, 'users', famA.uid, 'children', 'crianca-a', 'authorized_professionals', ped.uid), { revokedAt: F.serverTimestamp(), revokedBy: famA.uid })));
  rec('revogacao', 'NAO le a crianca', 'permission-denied', await outcome(() => F.getDoc(childRef(ped, famA, 'crianca-a'))));
  rec('revogacao', 'NAO edita o rascunho', 'permission-denied', await outcome(() => F.updateDoc(F.doc(ped.db, 'encounters', 'enc-a'), { plan: 'depois' })));
  rec('revogacao', 'NAO abre atendimento novo', 'permission-denied',
    await outcome(() => F.setDoc(F.doc(ped.db, 'encounters', 'enc-a2'), { patientId: 'crianca-a', professionalId: ped.uid, clinicId: CL, status: 'draft' })));
  const cr = await outcome(() => ped.call('checkChildAccess', { childId: 'crianca-a', clinicId: CL }));
  rec('revogacao', 'checkChildAccess informa revogada', 'sim', sim(cr.v && cr.v.state === 'revoked' && cr.v.chartWrite === false));
  rec('revogacao', 'IA clinica NAO roda', 'permission-denied', await outcome(() => ped.call('clinicalAssist', { task: 'summarizeEncounter', encounterId: 'enc-a' })));
  rec('revogacao', 'assinatura NAO roda', 'permission-denied', await outcome(() => ped.call('signEncounter', { encounterId: 'enc-a' })));
  rec('revogacao', 'consulta por voz NAO inicia', 'permission-denied', await outcome(() => ped.call('startVoiceConsultation', { childId: 'crianca-a', clinicId: CL })));
  rec('revogacao', 'listagem por crianca negada', 'permission-denied',
    await outcome(() => F.getDocs(F.query(F.collection(ped.db, 'encounters'), F.where('patientId', '==', 'crianca-a')))));
  rec('revogacao', 'politica atual: autor ainda le o proprio atendimento', 'permitido', await outcome(() => F.getDoc(F.doc(ped.db, 'encounters', 'enc-a'))));
  rec('revogacao', 'profissional NAO desfaz a revogacao', 'permission-denied',
    await outcome(() => F.updateDoc(F.doc(ped.db, 'users', famA.uid, 'children', 'crianca-a', 'authorized_professionals', ped.uid), { revokedAt: null })));

  // ------------------------------------------- Limite de tentativas de codigo
  let last = null;
  for (let k = 0; k < 11; k++) last = await outcome(() => famB.call('previewClinicIntake', { code: 'ZZZZZ-ZZZZ' + (k % 9 + 1) }));
  rec('tentativas', 'depois de 10 codigos errados, bloqueia', 'resource-exhausted', last);

  fs.writeFileSync(__dirname + '/etapa2_e2e.json', JSON.stringify(results, null, 2));
  const div = results.filter((r) => !r.ok).length;
  console.log('TOTAL ' + results.length + ' | divergencias ' + div);
  process.exit(div ? 1 : 0);
})().catch((e) => { console.error('FALHA', e); process.exit(2); });
