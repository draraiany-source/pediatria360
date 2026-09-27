/**
 * Testes das regras de segurança do Firestore.
 *
 * ## Por que estes testes existem
 *
 * O README afirma que as regras são a garantia real de isolamento, e que os
 * filtros no app são só conveniência de interface. Afirmação sobre segurança
 * de prontuário infantil precisa de prova executável, não de comentário.
 *
 * Cada teste aqui descreve um ataque concreto: um usuário tentando ler os
 * dados de saúde de outro, um pai tentando se dar plano premium, alguém
 * tentando forjar uma resposta da IA.
 *
 * ## Como rodar
 *
 *   cd test/rules
 *   npm install
 *   npm test
 *
 * O emulador do Firestore sobe sozinho pelo script.
 */

const fs = require("fs");
const path = require("path");
const { readFileSync } = require("fs");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  addDoc,
  getDocs,
  query,
  where,
  serverTimestamp,
  writeBatch,
} = require("firebase/firestore");
const {
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} = require("firebase/storage");

const PROJECT_ID = "pediatria360-rules-test";

/** Uids usados nos testes. */
const ANA = "uid_ana";        // mãe, plano gratuito
const BRUNO = "uid_bruno";    // outro responsável, sem relação com Ana
const DRA = "uid_dra";        // profissional VERIFICADA
const DR_NOVO = "uid_dr_novo"; // profissional NÃO verificado
const ADMIN = "uid_admin";

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8"
      ),
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      rules: readFileSync(
        path.resolve(__dirname, "../../storage.rules"),
        "utf8"
      ),
      host: "127.0.0.1",
      port: 9199,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();

  // Semeia os documentos de usuário ignorando as regras — é o estado que o
  // servidor cria, não algo que o cliente escreve.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, "users", ANA), {
      email: "ana@exemplo.com",
      name: "Ana Silva",
      role: "parent",
      plan: "free",
      professionalVerified: false,
      xp: 0,
    });

    await setDoc(doc(db, "users", BRUNO), {
      email: "bruno@exemplo.com",
      name: "Bruno Costa",
      role: "parent",
      plan: "free",
      professionalVerified: false,
      xp: 0,
    });

    await setDoc(doc(db, "users", DRA), {
      email: "dra@exemplo.com",
      name: "Dra. Marta",
      role: "professional",
      plan: "pro",
      professionalVerified: true,
      crm: "123456/SP",
      xp: 0,
    });

    await setDoc(doc(db, "users", DR_NOVO), {
      email: "novo@exemplo.com",
      name: "Dr. Novo",
      role: "professional",
      plan: "free",
      // Declarou-se profissional, mas a equipe ainda não conferiu o registro.
      professionalVerified: false,
      crm: "999999/SP",
      xp: 0,
    });

    await setDoc(doc(db, "users", ADMIN), {
      email: "admin@pediatria360.app",
      name: "Equipe",
      role: "admin",
      plan: "pro",
      professionalVerified: true,
      xp: 0,
    });

    // Filha da Ana, com uma medição e uma vacina.
    await setDoc(doc(db, "users", ANA, "children", "filha"), {
      ownerId: ANA,
      name: "Manuela",
      sex: "female",
    });
    await setDoc(doc(db, "child_registry", "filha"), { ownerUid: ANA });
    await setDoc(
      doc(db, "users", ANA, "children", "filha", "growth_records", "m1"),
      { weightKg: 9.6, heightCm: 75 }
    );
    await setDoc(
      doc(db, "users", ANA, "children", "filha", "vaccine_doses", "bcg-1"),
      { vaccineId: "bcg", doseIndex: 1, appliedAt: null }
    );

    // Atendimento da filha da Ana, conduzido pela Dra — para testar o
    // isolamento entre família/profissional em encounters/documentos/exames.
    // patientId é o id da CRIANÇA ("filha"), não o uid da Ana — mesmo
    // padrão que o repositório real grava.
    await setDoc(doc(db, "encounters", "atendimento-1"), {
      patientId: "filha",
      professionalId: DRA,
      status: "signed",
    });
    await setDoc(doc(db, "clinical_documents", "documento-1"), {
      patientId: "filha",
      professionalId: DRA,
      type: "prescription",
    });
    await setDoc(doc(db, "lab_results", "exame-1"), {
      patientId: "filha",
      professionalId: DRA,
      analyte: "Hemoglobina",
    });

    // Conteúdo da biblioteca.
    await setDoc(doc(db, "articles", "publico"), {
      title: "Febre",
      published: true,
      audience: "everyone",
    });
    await setDoc(doc(db, "articles", "so_pro"), {
      title: "Protocolo com posologia",
      published: true,
      audience: "professionals",
    });
    await setDoc(doc(db, "articles", "rascunho"), {
      title: "Não publicado",
      published: false,
      audience: "everyone",
    });

    // Conversa da Ana com a IA.
    await setDoc(doc(db, "ai_conversations", "conversa_ana"), {
      ownerId: ANA,
      title: "Dúvida sobre febre",
    });
    await setDoc(
      doc(db, "ai_conversations", "conversa_ana", "messages", "m1"),
      { role: "user", text: "Minha filha está com febre" }
    );

    // Pedido da Ana.
    await setDoc(doc(db, "orders", "pedido_ana"), {
      ownerId: ANA,
      totalCents: 5000,
      status: "pending",
    });

    // Cupom.
    await setDoc(doc(db, "coupons", "BEMVINDO10"), {
      active: true,
      type: "percent",
      value: 10,
    });

    // Consulta entre Ana e a Dra.
    await setDoc(doc(db, "appointments", "consulta1"), {
      patientId: ANA,
      professionalId: DRA,
      status: "confirmed",
      startsAt: new Date(),
    });

    // Consulta já concluída — para testar que o questionário de
    // pré-consulta não pode mais ser escrito depois do fato.
    await setDoc(doc(db, "appointments", "consulta-concluida"), {
      patientId: ANA,
      professionalId: DRA,
      status: "completed",
      startsAt: new Date(),
    });

    // Receita emitida na consulta.
    await setDoc(doc(db, "prescriptions", "receita1"), {
      patientId: ANA,
      professionalId: DRA,
      content: "...",
    });
  });
});

function as(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}
function anon() {
  return testEnv.unauthenticatedContext().firestore();
}
function asStorage(uid) {
  return testEnv.authenticatedContext(uid).storage();
}
function anonStorage() {
  return testEnv.unauthenticatedContext().storage();
}

// ===========================================================================
// Dados de saúde da criança — o que mais importa proteger
// ===========================================================================

describe("prontuário da criança", () => {
  test("a mãe lê os dados da própria filha", async () => {
    await assertSucceeds(
      getDoc(doc(as(ANA), "users", ANA, "children", "filha"))
    );
  });

  test("outro responsável NÃO lê os dados da filha alheia", async () => {
    await assertFails(
      getDoc(doc(as(BRUNO), "users", ANA, "children", "filha"))
    );
  });

  test("profissional verificado NÃO lê prontuário sem ser o dono", async () => {
    // Ser médico não dá acesso ao prontuário de qualquer criança do app.
    await assertFails(
      getDoc(doc(as(DRA), "users", ANA, "children", "filha"))
    );
  });

  test("nem o admin lê o prontuário", async () => {
    // Prontuário de criança não é dado operacional da equipe.
    await assertFails(
      getDoc(doc(as(ADMIN), "users", ANA, "children", "filha"))
    );
  });

  test("anônimo não lê nada", async () => {
    await assertFails(
      getDoc(doc(anon(), "users", ANA, "children", "filha"))
    );
  });

  test("medições de crescimento seguem a mesma regra", async () => {
    await assertSucceeds(
      getDoc(
        doc(as(ANA), "users", ANA, "children", "filha", "growth_records", "m1")
      )
    );
    await assertFails(
      getDoc(
        doc(as(BRUNO), "users", ANA, "children", "filha", "growth_records", "m1")
      )
    );
  });

  test("vacinas seguem a mesma regra", async () => {
    await assertSucceeds(
      getDoc(
        doc(as(ANA), "users", ANA, "children", "filha", "vaccine_doses", "bcg-1")
      )
    );
    await assertFails(
      getDoc(
        doc(as(DRA), "users", ANA, "children", "filha", "vaccine_doses", "bcg-1")
      )
    );
  });

  test("ninguém escreve na criança de outro", async () => {
    await assertFails(
      updateDoc(doc(as(BRUNO), "users", ANA, "children", "filha"), {
        name: "invadido",
      })
    );
  });
});

// ===========================================================================
// Escalada de privilégio
// ===========================================================================

describe("campos controlados pelo servidor", () => {
  test("usuário NÃO se dá plano premium", async () => {
    await assertFails(
      updateDoc(doc(as(ANA), "users", ANA), { plan: "premium" })
    );
  });

  test("usuário NÃO se dá XP", async () => {
    // Sem isso, liderar o ranking seria alterar um número.
    await assertFails(updateDoc(doc(as(ANA), "users", ANA), { xp: 999999 }));
  });

  test("usuário NÃO vira admin sozinho", async () => {
    await assertFails(
      updateDoc(doc(as(ANA), "users", ANA), { role: "admin" })
    );
  });

  test("profissional grava a própria disponibilidade semanal", async () => {
    // TelemedicineRepository.setWeeklyAvailability escreve isto direto no
    // Firestore, sem Function — o teste é a prova de que a regra realmente
    // permite, não só a suposição de que "não está bloqueado" seria
    // suficiente.
    await assertSucceeds(
      updateDoc(doc(as(DRA), "users", DRA), {
        availability: { "1": ["09:00", "09:30"] },
        consultationMinutes: 30,
      })
    );
  });

  test("profissional NÃO grava disponibilidade de outro profissional", async () => {
    await assertFails(
      updateDoc(doc(as(DR_NOVO), "users", DRA), {
        availability: { "1": ["09:00"] },
      })
    );
  });

  test("usuário NÃO grava fcmTokens direto — só a Function registra", async () => {
    // Centralizado em registerDevice/unregisterDevice desde que a
    // duplicação entre Function e escrita direta do cliente foi corrigida.
    // Sem esta regra, um cliente poderia ignorar a Function e escrever o
    // array à vontade, inclusive registrando token em nome de outra conta
    // se algum dia o isOwner() de outra regra tivesse uma brecha.
    await assertFails(
      updateDoc(doc(as(ANA), "users", ANA), {
        fcmTokens: ["token-forjado"],
      })
    );
  });

  test("profissional NÃO se autoverifica", async () => {
    // Este é o gate que libera posologias. Autoverificação anularia a
    // conferência manual do registro.
    await assertFails(
      updateDoc(doc(as(DR_NOVO), "users", DR_NOVO), {
        professionalVerified: true,
      })
    );
  });

  test("mas edita o próprio nome e telefone", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ANA), "users", ANA), {
        name: "Ana Silva Souza",
        phone: "11999999999",
      })
    );
  });

  test("admin pode verificar um profissional", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ADMIN), "users", DR_NOVO), {
        professionalVerified: true,
      })
    );
  });

  test("conta criada já vem sem privilégio", async () => {
    const novo = testEnv.authenticatedContext("uid_novo").firestore();

    await assertFails(
      setDoc(doc(novo, "users", "uid_novo"), {
        email: "x@y.z",
        name: "X",
        role: "admin", // tentativa de nascer admin
        plan: "free",
        xp: 0,
      })
    );

    await assertFails(
      setDoc(doc(novo, "users", "uid_novo"), {
        email: "x@y.z",
        name: "X",
        role: "parent",
        plan: "pro", // tentativa de nascer com plano pago
        xp: 0,
      })
    );

    await assertSucceeds(
      setDoc(doc(novo, "users", "uid_novo"), {
        email: "x@y.z",
        name: "X",
        role: "parent",
        plan: "free",
        professionalVerified: false,
        xp: 0,
      })
    );
  });

  test("ninguém apaga o próprio documento direto", async () => {
    // A exclusão passa por Function, que remove em cascata. Apagar só o
    // documento deixaria crianças e medições órfãs.
    await assertFails(deleteDoc(doc(as(ANA), "users", ANA)));
  });
});

// ===========================================================================
// Biblioteca: conteúdo de prescrição
// ===========================================================================

describe("biblioteca", () => {
  test("conteúdo público é lido por qualquer usuário logado", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "articles", "publico")));
  });

  test("responsável NÃO lê protocolo com posologia", async () => {
    // Um protocolo de conduta lido por um pai às 3h é risco de automedicação.
    await assertFails(getDoc(doc(as(ANA), "articles", "so_pro")));
  });

  test("profissional NÃO verificado também não lê", async () => {
    // Declarar CRM no cadastro não vale como credencial.
    await assertFails(getDoc(doc(as(DR_NOVO), "articles", "so_pro")));
  });

  test("profissional verificado lê", async () => {
    await assertSucceeds(getDoc(doc(as(DRA), "articles", "so_pro")));
  });

  test("rascunho não publicado fica invisível", async () => {
    await assertFails(getDoc(doc(as(ANA), "articles", "rascunho")));
  });

  test("admin lê inclusive rascunho", async () => {
    await assertSucceeds(getDoc(doc(as(ADMIN), "articles", "rascunho")));
  });

  test("usuário comum não publica conteúdo", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "articles", "falso"), {
        title: "Conteúdo forjado",
        published: true,
        audience: "everyone",
      })
    );
  });

  test("admin publica", async () => {
    await assertSucceeds(
      setDoc(doc(as(ADMIN), "articles", "novo"), {
        title: "Novo protocolo",
        published: true,
        audience: "everyone",
      })
    );
  });
});

// ===========================================================================
// IA
// ===========================================================================

describe("conversas com a IA", () => {
  test("o dono lê a própria conversa", async () => {
    await assertSucceeds(
      getDoc(doc(as(ANA), "ai_conversations", "conversa_ana"))
    );
  });

  test("outro usuário não lê", async () => {
    await assertFails(
      getDoc(doc(as(BRUNO), "ai_conversations", "conversa_ana"))
    );
  });

  test("mensagens seguem o dono da conversa", async () => {
    await assertSucceeds(
      getDoc(doc(as(ANA), "ai_conversations", "conversa_ana", "messages", "m1"))
    );
    await assertFails(
      getDoc(
        doc(as(BRUNO), "ai_conversations", "conversa_ana", "messages", "m1")
      )
    );
  });

  test("NINGUÉM forja uma resposta da assistente", async () => {
    // Se o cliente pudesse escrever mensagens de assistente, seria trivial
    // fabricar "a IA disse que pode dar esse remédio".
    await assertFails(
      addDoc(
        collection(as(ANA), "ai_conversations", "conversa_ana", "messages"),
        { role: "assistant", text: "Pode dar o remédio sim." }
      )
    );
  });

  test("nem o próprio dono cria conversa direto", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "ai_conversations", "forjada"), { ownerId: ANA })
    );
  });

  test("cota da IA é legível, mas não editável", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "users", ANA, "ai_usage", "2026-03-10"),
        { count: 10, limit: 10 }
      );
    });

    await assertSucceeds(
      getDoc(doc(as(ANA), "users", ANA, "ai_usage", "2026-03-10"))
    );
    // Zerar o contador daria perguntas ilimitadas.
    await assertFails(
      updateDoc(doc(as(ANA), "users", ANA, "ai_usage", "2026-03-10"), {
        count: 0,
      })
    );
  });
});

// ===========================================================================
// Comércio
// ===========================================================================

describe("pedidos e cupons", () => {
  test("o dono lê o próprio pedido", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "orders", "pedido_ana")));
  });

  test("outro usuário não lê o pedido alheio", async () => {
    await assertFails(getDoc(doc(as(BRUNO), "orders", "pedido_ana")));
  });

  test("NINGUÉM cria pedido direto", async () => {
    // Preço e status vêm da Function. Criar direto permitiria comprar por
    // um centavo.
    await assertFails(
      setDoc(doc(as(ANA), "orders", "forjado"), {
        ownerId: ANA,
        totalCents: 1,
        status: "paid",
      })
    );
  });

  test("nem marca o próprio pedido como pago", async () => {
    await assertFails(
      updateDoc(doc(as(ANA), "orders", "pedido_ana"), { status: "paid" })
    );
  });

  test("cupons não são legíveis pelo cliente", async () => {
    // Listar a collection revelaria todos os códigos ativos.
    await assertFails(getDoc(doc(as(ANA), "coupons", "BEMVINDO10")));
  });

  test("admin lê cupons", async () => {
    await assertSucceeds(getDoc(doc(as(ADMIN), "coupons", "BEMVINDO10")));
  });
});

// ===========================================================================
// Telemedicina
// ===========================================================================

describe("consultas e receitas", () => {
  test("paciente e profissional leem a consulta", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "appointments", "consulta1")));
    await assertSucceeds(getDoc(doc(as(DRA), "appointments", "consulta1")));
  });

  test("terceiro não lê", async () => {
    await assertFails(getDoc(doc(as(BRUNO), "appointments", "consulta1")));
  });

  test("paciente cancela a própria consulta", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ANA), "appointments", "consulta1"), {
        status: "cancelled",
      })
    );
  });

  test("paciente NÃO marca a consulta como realizada", async () => {
    // Confirmar atendimento é ato do profissional.
    await assertFails(
      updateDoc(doc(as(ANA), "appointments", "consulta1"), {
        status: "completed",
      })
    );
  });

  test("profissional atualiza a própria agenda", async () => {
    await assertSucceeds(
      updateDoc(doc(as(DRA), "appointments", "consulta1"), {
        status: "completed",
        notes: "Evolução...",
      })
    );
  });

  test("receita é lida só por paciente e prescritor", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "prescriptions", "receita1")));
    await assertSucceeds(getDoc(doc(as(DRA), "prescriptions", "receita1")));
    await assertFails(getDoc(doc(as(BRUNO), "prescriptions", "receita1")));
    // Nem o admin: receita médica não é dado operacional.
    await assertFails(getDoc(doc(as(ADMIN), "prescriptions", "receita1")));
  });

  test("ninguém emite receita pelo cliente", async () => {
    await assertFails(
      setDoc(doc(as(DRA), "prescriptions", "forjada"), {
        patientId: ANA,
        professionalId: DRA,
        content: "...",
      })
    );
  });
});

// ===========================================================================
// Gamificação
// ===========================================================================

describe("ranking", () => {
  test("é legível por quem está logado", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "leaderboard", ANA), {
        uid: ANA,
        displayName: "Ana S.",
        xp: 500,
        position: 1,
      });
    });

    await assertSucceeds(getDoc(doc(as(BRUNO), "leaderboard", ANA)));
  });

  test("ninguém escreve no ranking", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "leaderboard", ANA), {
        uid: ANA,
        displayName: "Ana S.",
        xp: 999999,
        position: 1,
      })
    );
  });
});

// ===========================================================================
// Fechamento por padrão
// ===========================================================================

describe("collections não declaradas", () => {
  test("nascem fechadas", async () => {
    // Uma collection nova criada por engano não deve nascer pública.
    await assertFails(
      setDoc(doc(as(ANA), "colecao_inventada", "x"), { qualquer: "coisa" })
    );
    await assertFails(getDoc(doc(as(ANA), "colecao_inventada", "x")));
  });

  test("audit_log não é acessível pelo cliente", async () => {
    await assertFails(
      addDoc(collection(as(ADMIN), "audit_log"), { action: "x" })
    );
  });
});

// ===========================================================================
// Storage — fotos de perfil, de crianças, comprovante de vacina
// ===========================================================================
//
// Mesma razão de existir dos testes de Firestore acima: "só o dono lê e
// escreve" é uma afirmação sobre dado sensível de menor, e precisa de prova
// executável. Faltava inteiramente até esta rodada — os 50 testes acima
// cobrem Firestore, nenhum cobria Storage, mesmo o comando do emulador já
// incluindo os dois.

const PNG_BYTES = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]); // assinatura PNG
const TEXT_BYTES = new Uint8Array([104, 105]); // "hi", não é imagem

describe("Storage — arquivo de usuário", () => {
  test("dono envia imagem dentro do limite de tamanho", async () => {
    await assertSucceeds(
      uploadBytes(
        ref(asStorage(ANA), `users/${ANA}/foto.png`),
        PNG_BYTES,
        { contentType: "image/png" }
      )
    );
  });

  test("dono NÃO envia arquivo que não é imagem", async () => {
    // A regra exige `image/.*` no content-type — um PDF de laudo, por
    // exemplo, não deveria caber aqui (vai para outro caminho, gerado só
    // pela Function).
    await assertFails(
      uploadBytes(
        ref(asStorage(ANA), `users/${ANA}/documento.txt`),
        TEXT_BYTES,
        { contentType: "text/plain" }
      )
    );
  });

  test("dono NÃO envia arquivo acima de 8 MB", async () => {
    const big = new Uint8Array(8 * 1024 * 1024 + 1);
    await assertFails(
      uploadBytes(ref(asStorage(ANA), `users/${ANA}/grande.png`), big, {
        contentType: "image/png",
      })
    );
  });

  test("usuário NÃO envia arquivo no caminho de outro usuário", async () => {
    // O ataque mais direto: Bruno tentando escrever dentro da pasta da Ana.
    await assertFails(
      uploadBytes(
        ref(asStorage(BRUNO), `users/${ANA}/foto.png`),
        PNG_BYTES,
        { contentType: "image/png" }
      )
    );
  });

  test("dono lê o próprio arquivo", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(
        ref(context.storage(), `users/${ANA}/foto.png`),
        PNG_BYTES,
        { contentType: "image/png" }
      );
    });
    await assertSucceeds(
      getBytes(ref(asStorage(ANA), `users/${ANA}/foto.png`))
    );
  });

  test("usuário NÃO lê arquivo de outro usuário", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(
        ref(context.storage(), `users/${ANA}/foto.png`),
        PNG_BYTES,
        { contentType: "image/png" }
      );
    });
    await assertFails(
      getBytes(ref(asStorage(BRUNO), `users/${ANA}/foto.png`))
    );
  });

  test("profissional NÃO lê arquivo de paciente só por ser profissional", async () => {
    // Mesmo princípio do isolamento no Firestore: verificação profissional
    // não abre a pasta de ninguém — só o próprio dono.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(
        ref(context.storage(), `users/${ANA}/comprovante_vacina.png`),
        PNG_BYTES,
        { contentType: "image/png" }
      );
    });
    await assertFails(
      getBytes(ref(asStorage(DRA), `users/${ANA}/comprovante_vacina.png`))
    );
  });

  test("usuário anônimo NÃO lê nem escreve em pasta de usuário", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(
        ref(context.storage(), `users/${ANA}/foto.png`),
        PNG_BYTES,
        { contentType: "image/png" }
      );
    });
    await assertFails(getBytes(ref(anonStorage(), `users/${ANA}/foto.png`)));
    await assertFails(
      uploadBytes(ref(anonStorage(), `users/${ANA}/outra.png`), PNG_BYTES, {
        contentType: "image/png",
      })
    );
  });

  test("dono apaga o próprio arquivo", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(
        ref(context.storage(), `users/${ANA}/apagar.png`),
        PNG_BYTES,
        { contentType: "image/png" }
      );
    });
    await assertSucceeds(
      deleteObject(ref(asStorage(ANA), `users/${ANA}/apagar.png`))
    );
  });

  test("usuário NÃO apaga arquivo de outro usuário", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(
        ref(context.storage(), `users/${ANA}/naoapagar.png`),
        PNG_BYTES,
        { contentType: "image/png" }
      );
    });
    await assertFails(
      deleteObject(ref(asStorage(BRUNO), `users/${ANA}/naoapagar.png`))
    );
  });
});

describe("Storage — caminho público", () => {
  test("qualquer um lê, mesmo sem login", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(
        ref(context.storage(), "public/curso-capa.png"),
        PNG_BYTES,
        { contentType: "image/png" }
      );
    });
    await assertSucceeds(
      getBytes(ref(anonStorage(), "public/curso-capa.png"))
    );
  });

  test("cliente autenticado NÃO escreve em /public — só admin via console ou Function", async () => {
    await assertFails(
      uploadBytes(
        ref(asStorage(ANA), "public/forjado.png"),
        PNG_BYTES,
        { contentType: "image/png" }
      )
    );
  });
});

describe("Storage — caminho não declarado", () => {
  test("nasce fechado, mesmo autenticado", async () => {
    await assertFails(
      uploadBytes(
        ref(asStorage(ANA), "caminho-inventado/x.png"),
        PNG_BYTES,
        { contentType: "image/png" }
      )
    );
  });
});

// ===========================================================================
// Isolamento em encounters/clinical_documents/lab_results — o bug real
// ===========================================================================
//
// As três regras abaixo comparavam `patientId == request.auth.uid`, mas
// `patientId` é id de criança, não de usuário — essa comparação nunca batia
// para o responsável. Nenhum destes três testes existia antes: o bug
// sobreviveu porque nada o exercitava, nem em produção (nenhuma tela de
// responsável usava este caminho) nem em teste. Corrigido com `ownsChild()`.
// `lab_results` tinha um segundo bug, de precedência: `&&` liga mais forte
// que `||`, então a regra antiga liberava QUALQUER profissional verificado
// para QUALQUER exame, não só dos pacientes que atende.

describe("encounters — isolamento por família e por vínculo profissional", () => {
  test("responsável lê o atendimento do próprio filho", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "encounters", "atendimento-1")));
  });

  test("responsável NÃO lê atendimento de criança de outra família", async () => {
    await assertFails(getDoc(doc(as(BRUNO), "encounters", "atendimento-1")));
  });

  test("profissional que conduziu o atendimento lê", async () => {
    await assertSucceeds(getDoc(doc(as(DRA), "encounters", "atendimento-1")));
  });

  test("profissional SEM vínculo com este atendimento NÃO lê", async () => {
    // DR_NOVO nunca atendeu esta criança — só ser profissional verificado
    // não deveria bastar.
    await assertFails(
      getDoc(doc(as(DR_NOVO), "encounters", "atendimento-1"))
    );
  });

  test("admin NÃO lê — prontuário não é dado operacional da equipe", async () => {
    await assertFails(getDoc(doc(as(ADMIN), "encounters", "atendimento-1")));
  });
});

describe("clinical_documents — mesmo isolamento", () => {
  test("responsável lê o documento do próprio filho", async () => {
    await assertSucceeds(
      getDoc(doc(as(ANA), "clinical_documents", "documento-1"))
    );
  });

  test("responsável NÃO lê documento de criança de outra família", async () => {
    await assertFails(
      getDoc(doc(as(BRUNO), "clinical_documents", "documento-1"))
    );
  });

  test("profissional sem vínculo NÃO lê", async () => {
    await assertFails(
      getDoc(doc(as(DR_NOVO), "clinical_documents", "documento-1"))
    );
  });
});

describe("lab_results — isolamento, incluindo o bug de precedência corrigido", () => {
  test("responsável lê o exame do próprio filho", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "lab_results", "exame-1")));
  });

  test("responsável NÃO lê exame de criança de outra família", async () => {
    await assertFails(getDoc(doc(as(BRUNO), "lab_results", "exame-1")));
  });

  test("profissional que pediu o exame lê", async () => {
    await assertSucceeds(getDoc(doc(as(DRA), "lab_results", "exame-1")));
  });

  test("profissional SEM vínculo NÃO lê — este é o bug de precedência: antes, qualquer verificado lia", async () => {
    await assertFails(getDoc(doc(as(DR_NOVO), "lab_results", "exame-1")));
  });
});

// ===========================================================================
// children/{childId} — concessão de acesso ao resumo de segurança
// ===========================================================================
//
// `grantChildSummaryAccess` (Cloud Function, roda com Admin SDK) escreve a
// concessão — o cliente nunca escreve isto diretamente para outro uid que
// não o próprio. Os testes abaixo confirmam a regra que protege essa
// concessão, não a Function em si (que exigiria emulador de Functions,
// fora do escopo desta suíte).

describe("children — concessão de acesso do profissional", () => {
  test("dono continua lendo sem nenhuma concessão", async () => {
    await assertSucceeds(
      getDoc(doc(as(ANA), "users", ANA, "children", "filha"))
    );
  });

  test("profissional SEM concessão NÃO lê a criança", async () => {
    await assertFails(
      getDoc(doc(as(DRA), "users", ANA, "children", "filha"))
    );
  });

  test("profissional COM concessão lê a criança", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          "users", ANA, "children", "filha",
          "authorized_professionals", DRA
        ),
        { grantedAt: serverTimestamp() }
      );
    });
    await assertSucceeds(
      getDoc(doc(as(DRA), "users", ANA, "children", "filha"))
    );
  });

  test("profissional NÃO escreve a própria concessão (só o responsável ou Function)", async () => {
    // Auto-concessão pelo cliente foi removida — risco LGPD. O vínculo
    // passa por grantChildSummaryAccess (Admin SDK) ou pelo dono.
    await assertFails(
      setDoc(
        doc(
          as(DRA),
          "users", ANA, "children", "filha",
          "authorized_professionals", DRA
        ),
        { grantedAt: serverTimestamp() }
      )
    );
  });

  test("responsável concede acesso a um profissional", async () => {
    await assertSucceeds(
      setDoc(
        doc(
          as(ANA),
          "users", ANA, "children", "filha",
          "authorized_professionals", DRA
        ),
        { grantedAt: serverTimestamp() }
      )
    );
  });

  test("profissional NÃO escreve concessão em nome de outro profissional", async () => {
    await assertFails(
      setDoc(
        doc(
          as(DRA),
          "users", ANA, "children", "filha",
          "authorized_professionals", DR_NOVO
        ),
        { grantedAt: serverTimestamp() }
      )
    );
  });

  test("responsável de outra família NÃO concede acesso a esta criança", async () => {
    await assertFails(
      setDoc(
        doc(
          as(BRUNO),
          "users", ANA, "children", "filha",
          "authorized_professionals", DRA
        ),
        { grantedAt: serverTimestamp() }
      )
    );
  });

  test("concessão continua sem dar acesso a growth_records/vaccine_doses", async () => {
    // A concessão é só para o documento da criança em si — dado clínico
    // nas subcoleções continua exclusivo do dono, mesmo com a concessão.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(
          context.firestore(),
          "users", ANA, "children", "filha",
          "authorized_professionals", DRA
        ),
        { grantedAt: serverTimestamp() }
      );
    });
    await assertFails(
      getDoc(
        doc(
          as(DRA),
          "users", ANA, "children", "filha", "growth_records", "m1"
        )
      )
    );
  });
});

// ===========================================================================
// pre_visit_questionnaires — Fase 2, Pré-consulta Digital
// ===========================================================================
//
// Documento com o mesmo id do agendamento. Só o responsável escreve; o
// profissional só lê. Escrita bloqueada depois que a consulta já
// aconteceu (status deixa de ser requested/confirmed) — o questionário é
// o que a família disse ANTES, não deveria virar editável depois do fato.

describe("pre_visit_questionnaires", () => {
  test("responsável escreve o próprio questionário, consulta ainda não aconteceu", async () => {
    await assertSucceeds(
      setDoc(doc(as(ANA), "pre_visit_questionnaires", "consulta1"), {
        patientId: ANA,
        childId: "filha",
        professionalId: DRA,
        reason: "febre",
      })
    );
  });

  test("outro responsável NÃO escreve reivindicando ser o paciente da consulta", async () => {
    await assertFails(
      setDoc(doc(as(BRUNO), "pre_visit_questionnaires", "consulta1"), {
        patientId: BRUNO,
        childId: "filha",
        professionalId: DRA,
        reason: "tentativa forjada",
      })
    );
  });

  test("responsável NÃO escreve com professionalId que não bate com o agendamento", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "pre_visit_questionnaires", "consulta1"), {
        patientId: ANA,
        childId: "filha",
        professionalId: DR_NOVO, // agendamento real é com a Dra, não Dr. Novo
        reason: "professionalId forjado",
      })
    );
  });

  test("NÃO escreve depois que a consulta já aconteceu (status completed)", async () => {
    await assertFails(
      setDoc(
        doc(as(ANA), "pre_visit_questionnaires", "consulta-concluida"),
        { patientId: ANA, childId: "filha", professionalId: DRA, reason: "tarde demais" }
      )
    );
  });

  test("responsável lê o próprio questionário", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "pre_visit_questionnaires", "consulta1"),
        { patientId: ANA, childId: "filha", professionalId: DRA, reason: "febre" }
      );
    });
    await assertSucceeds(
      getDoc(doc(as(ANA), "pre_visit_questionnaires", "consulta1"))
    );
  });

  test("profissional designado lê o questionário", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "pre_visit_questionnaires", "consulta1"),
        { patientId: ANA, childId: "filha", professionalId: DRA, reason: "febre" }
      );
    });
    await assertSucceeds(
      getDoc(doc(as(DRA), "pre_visit_questionnaires", "consulta1"))
    );
  });

  test("profissional SEM vínculo com esta consulta NÃO lê", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "pre_visit_questionnaires", "consulta1"),
        { patientId: ANA, childId: "filha", professionalId: DRA, reason: "febre" }
      );
    });
    await assertFails(
      getDoc(doc(as(DR_NOVO), "pre_visit_questionnaires", "consulta1"))
    );
  });

  test("outro responsável NÃO lê o questionário de família alheia", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "pre_visit_questionnaires", "consulta1"),
        { patientId: ANA, childId: "filha", professionalId: DRA, reason: "febre" }
      );
    });
    await assertFails(
      getDoc(doc(as(BRUNO), "pre_visit_questionnaires", "consulta1"))
    );
  });
});

// ===========================================================================
// visit_summaries — Fase 2, Resumo Pós-consulta para a Família
// ===========================================================================
//
// patientId aqui é id de criança (herdado da convenção de Encounter, não
// de Appointment) — a regra já nasce usando ownsChild(), não a comparação
// direta que precisou ser corrigida três vezes em outras coleções nesta
// mesma série.

describe("visit_summaries", () => {
  test("profissional cria rascunho", async () => {
    await assertSucceeds(
      setDoc(doc(as(DRA), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "draft",
        guidance: "Manter hidratação",
      })
    );
  });

  test("profissional NÃO cria já como released — tem que nascer draft", async () => {
    await assertFails(
      setDoc(doc(as(DRA), "visit_summaries", "atendimento-2"), {
        patientId: "filha",
        professionalId: DRA,
        status: "released",
        guidance: "tentando pular a revisão",
      })
    );
  });

  test("profissional lê o próprio rascunho", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "draft",
      });
    });
    await assertSucceeds(
      getDoc(doc(as(DRA), "visit_summaries", "atendimento-1"))
    );
  });

  test("família NÃO lê rascunho — só depois de liberado", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "draft",
      });
    });
    await assertFails(
      getDoc(doc(as(ANA), "visit_summaries", "atendimento-1"))
    );
  });

  test("família lê depois de liberado", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "released",
      });
    });
    await assertSucceeds(
      getDoc(doc(as(ANA), "visit_summaries", "atendimento-1"))
    );
  });

  test("responsável de outra família NÃO lê, mesmo liberado", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "released",
      });
    });
    await assertFails(
      getDoc(doc(as(BRUNO), "visit_summaries", "atendimento-1"))
    );
  });

  test("profissional SEM vínculo NÃO lê nem rascunho nem liberado", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "released",
      });
    });
    await assertFails(
      getDoc(doc(as(DR_NOVO), "visit_summaries", "atendimento-1"))
    );
  });

  test("família NUNCA escreve, nem no próprio resumo liberado", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "released",
      });
    });
    await assertFails(
      updateDoc(doc(as(ANA), "visit_summaries", "atendimento-1"), {
        guidance: "família tentando editar o próprio resumo",
      })
    );
  });

  test("profissional autor finaliza (draft → finalized)", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "draft",
      });
    });
    await assertSucceeds(
      updateDoc(doc(as(DRA), "visit_summaries", "atendimento-1"), {
        status: "finalized",
      })
    );
  });

  test("profissional autor libera depois de finalizado (finalized → released)", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "finalized",
      });
    });
    await assertSucceeds(
      updateDoc(doc(as(DRA), "visit_summaries", "atendimento-1"), {
        status: "released",
      })
    );
  });

  test("NÃO pula direto de draft para released — regra impõe a sequência, não só o app", async () => {
    // Mesmo se o repositório sempre passasse por finalized, uma escrita
    // direta ao Firestore (sem o app) não deveria conseguir pular a etapa.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "draft",
      });
    });
    await assertFails(
      updateDoc(doc(as(DRA), "visit_summaries", "atendimento-1"), {
        status: "released",
      })
    );
  });

  test("NÃO edita um resumo já liberado — imutável de verdade", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "released",
      });
    });
    await assertFails(
      updateDoc(doc(as(DRA), "visit_summaries", "atendimento-1"), {
        guidance: "tentando editar depois de liberado",
      })
    );
  });

  test("retificação: cria documento novo referenciando o original liberado", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "released",
      });
    });
    await assertSucceeds(
      setDoc(doc(as(DRA), "visit_summaries", "atendimento-1_amend_123"), {
        patientId: "filha",
        professionalId: DRA,
        status: "draft",
        amendsSummaryId: "atendimento-1",
        amendmentReason: "Corrigindo orientação de dose",
      })
    );
  });

  test("profissional NÃO reatribui o resumo para outro paciente na atualização", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "draft",
      });
    });
    await assertFails(
      updateDoc(doc(as(DRA), "visit_summaries", "atendimento-1"), {
        patientId: "outra-crianca",
      })
    );
  });

  test("profissional SEM vínculo NÃO edita rascunho de outro profissional", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "visit_summaries", "atendimento-1"), {
        patientId: "filha",
        professionalId: DRA,
        status: "draft",
      });
    });
    await assertFails(
      updateDoc(doc(as(DR_NOVO), "visit_summaries", "atendimento-1"), {
        guidance: "tentando editar resumo de outro profissional",
      })
    );
  });
});

// ===========================================================================
// child_registry — posse da crianca nao pode ser forjada
// ===========================================================================

describe("child_registry — posse da crianca", () => {
  function novaCriancaComRegistro(db, owner, childId) {
    const batch = writeBatch(db);
    batch.set(doc(db, "users", owner, "children", childId), {
      ownerId: owner,
      name: "Crianca ficticia",
    });
    batch.set(doc(db, "child_registry", childId), { ownerUid: owner });
    return batch.commit();
  }

  test("a mae cadastra crianca nova junto com o registro", async () => {
    await assertSucceeds(novaCriancaComRegistro(as(ANA), ANA, "novo"));
  });

  test("cadastro de crianca SEM registro e recusado", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "users", ANA, "children", "sem-registro"), {
        ownerId: ANA,
        name: "Crianca ficticia",
      })
    );
  });

  test("outro responsavel NAO cria documento com o id da filha alheia", async () => {
    await assertFails(novaCriancaComRegistro(as(BRUNO), BRUNO, "filha"));
    await assertFails(
      setDoc(doc(as(BRUNO), "users", BRUNO, "children", "filha"), {
        ownerId: BRUNO,
      })
    );
  });

  test("registro sem a crianca correspondente e recusado", async () => {
    await assertFails(
      setDoc(doc(as(BRUNO), "child_registry", "qualquer"), { ownerUid: BRUNO })
    );
  });

  test("registro em nome de outra pessoa e recusado", async () => {
    const db = as(BRUNO);
    const batch = writeBatch(db);
    batch.set(doc(db, "users", BRUNO, "children", "x1"), { ownerId: BRUNO });
    batch.set(doc(db, "child_registry", "x1"), { ownerUid: ANA });
    await assertFails(batch.commit());
  });

  test("registro nao pode ser alterado nem apagado", async () => {
    await assertFails(
      updateDoc(doc(as(ANA), "child_registry", "filha"), { ownerUid: BRUNO })
    );
    await assertFails(deleteDoc(doc(as(ANA), "child_registry", "filha")));
  });

  test("dono le o proprio registro; outro nao", async () => {
    await assertSucceeds(getDoc(doc(as(ANA), "child_registry", "filha")));
    await assertFails(getDoc(doc(as(BRUNO), "child_registry", "filha")));
  });

  test("documento-isca antigo NAO da acesso ao prontuario quando ha registro", async () => {
    // Simula um documento forjado antes desta regra existir.
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "users", BRUNO, "children", "filha"),
        { ownerId: BRUNO }
      );
    });
    await assertFails(getDoc(doc(as(BRUNO), "encounters", "atendimento-1")));
    await assertFails(getDoc(doc(as(BRUNO), "lab_results", "exame-1")));
    await assertSucceeds(getDoc(doc(as(ANA), "encounters", "atendimento-1")));
  });

  test("crianca antiga sem registro continua acessivel ao dono", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users", ANA, "children", "legado"), {
        ownerId: ANA,
      });
      await setDoc(doc(db, "encounters", "atendimento-legado"), {
        patientId: "legado",
        professionalId: DRA,
        status: "signed",
      });
    });
    await assertSucceeds(
      getDoc(doc(as(ANA), "encounters", "atendimento-legado"))
    );
    await assertSucceeds(
      updateDoc(doc(as(ANA), "users", ANA, "children", "legado"), {
        name: "Atualizado",
      })
    );
  });

  test("a mae atualiza o cadastro da filha registrada", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ANA), "users", ANA, "children", "filha"), {
        name: "Manuela Silva",
      })
    );
  });
});

// ===========================================================================
// Registros clinicos — atualizacao so pelo autor atual
// ===========================================================================

describe("registros clinicos — sem sequestro na atualizacao", () => {
  const DRA2 = "uid_dra2";

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "users", DRA2), {
        email: "dra2@exemplo.com",
        name: "Dra. Ficticia 2",
        role: "professional",
        plan: "pro",
        professionalVerified: true,
        xp: 0,
      });
      await setDoc(doc(db, "triage_records", "t1"), {
        childId: "filha",
        professionalId: DRA,
      });
      await setDoc(doc(db, "development_records", "d1"), {
        childId: "filha",
        professionalId: DRA,
      });
      await setDoc(doc(db, "supplement_lab_results", "s1"), {
        childId: "filha",
        recordedBy: DRA,
      });
      await setDoc(doc(db, "supplement_prescriptions", "p1"), {
        childId: "filha",
        professionalId: DRA,
        status: "draft",
      });
      await setDoc(doc(db, "supplement_clinical_notes", "n1"), {
        childId: "filha",
        professionalId: DRA,
        text: "nota ficticia",
      });
      await setDoc(doc(db, "supplement_ai_drafts", "a1"), {
        childId: "filha",
        professionalId: DRA,
      });
    });
  });

  const alvos = [
    ["lab_results", "exame-1", "professionalId"],
    ["triage_records", "t1", "professionalId"],
    ["development_records", "d1", "professionalId"],
    ["supplement_lab_results", "s1", "recordedBy"],
    ["supplement_prescriptions", "p1", "professionalId"],
    ["supplement_clinical_notes", "n1", "professionalId"],
  ];

  test.each(alvos)(
    "outro profissional NAO grava o proprio id em %s alheio",
    async (col, id, campo) => {
      await assertFails(
        setDoc(doc(as(DRA2), col, id), { [campo]: DRA2 }, { merge: true })
      );
    }
  );

  test.each(alvos)("autor atualiza o proprio registro em %s", async (col, id) => {
    await assertSucceeds(
      setDoc(doc(as(DRA), col, id), { nota: "revisado" }, { merge: true })
    );
  });

  test("autor NAO troca o paciente do registro", async () => {
    await assertFails(
      updateDoc(doc(as(DRA), "triage_records", "t1"), { childId: "outra" })
    );
    await assertFails(
      updateDoc(doc(as(DRA), "lab_results", "exame-1"), { patientId: "outra" })
    );
  });

  test("autor NAO repassa o registro para outro profissional", async () => {
    await assertFails(
      updateDoc(doc(as(DRA), "development_records", "d1"), {
        professionalId: DRA2,
      })
    );
  });

  test("autor le as proprias notas e rascunhos de suplementacao", async () => {
    await assertSucceeds(getDoc(doc(as(DRA), "supplement_clinical_notes", "n1")));
    await assertSucceeds(getDoc(doc(as(DRA), "supplement_ai_drafts", "a1")));
    await assertFails(getDoc(doc(as(DRA2), "supplement_clinical_notes", "n1")));
    await assertFails(getDoc(doc(as(DRA2), "supplement_ai_drafts", "a1")));
  });
});

// ===========================================================================
// Vinculo com a clinica, agendamentos e responsaveis vinculados
// ===========================================================================

describe("clinica, agendamentos e responsaveis vinculados", () => {
  const REC = "uid_recepcao";
  const FIN = "uid_financeiro";
  const CLIN = "clinica-ficticia";

  async function vinculo(db, uid, role, { ativoClinica = true, papelClinica } = {}) {
    await setDoc(doc(db, "users", uid, "clinic_memberships", CLIN), {
      id: uid,
      userId: uid,
      clinicId: CLIN,
      role,
      active: true,
    });
    await setDoc(doc(db, "clinics", CLIN, "memberships", uid), {
      id: uid,
      userId: uid,
      clinicId: CLIN,
      role: papelClinica || role,
      active: ativoClinica,
    });
  }

  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      for (const uid of [REC, FIN]) {
        await setDoc(doc(db, "users", uid), {
          role: "professional",
          professionalVerified: true,
          plan: "free",
          xp: 0,
        });
      }
      await vinculo(db, REC, "receptionist");
      await vinculo(db, FIN, "finance");
      await setDoc(doc(db, "appointments", "consulta-clinica"), {
        patientId: ANA,
        professionalId: DRA,
        clinicId: CLIN,
        childId: "filha",
        status: "confirmed",
        startsAt: new Date(),
      });
      await setDoc(
        doc(db, "users", ANA, "children", "filha", "guardians", BRUNO),
        {
          ownerId: ANA,
          childId: "filha",
          guardianUid: BRUNO,
          status: "active",
          canViewData: true,
        }
      );
    });
  });

  test("recepcao ativa le a agenda da clinica", async () => {
    await assertSucceeds(getDoc(doc(as(REC), "appointments", "consulta-clinica")));
  });

  test("recepcao desativada NA CLINICA perde o acesso (copia do usuario velha)", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await vinculo(context.firestore(), REC, "receptionist", { ativoClinica: false });
    });
    await assertFails(getDoc(doc(as(REC), "appointments", "consulta-clinica")));
  });

  test("papel rebaixado na clinica vale sobre a copia do usuario", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await vinculo(context.firestore(), REC, "receptionist", { papelClinica: "finance" });
    });
    await assertFails(getDoc(doc(as(REC), "appointments", "consulta-clinica")));
  });

  test("financeiro marca o atendimento como pago, e so isso", async () => {
    await assertSucceeds(
      updateDoc(doc(as(FIN), "appointments", "consulta-clinica"), { paid: true })
    );
    await assertFails(
      updateDoc(doc(as(FIN), "appointments", "consulta-clinica"), {
        status: "cancelled",
      })
    );
  });

  test("paciente cancela, mas nao muda outros campos junto", async () => {
    await assertSucceeds(
      updateDoc(doc(as(ANA), "appointments", "consulta1"), {
        status: "cancelled",
        cancelledAt: serverTimestamp(),
      })
    );
    await assertFails(
      updateDoc(doc(as(ANA), "appointments", "consulta-concluida"), {
        status: "cancelled",
        paid: true,
      })
    );
  });

  test("paciente solicita consulta simples para crianca propria", async () => {
    await assertSucceeds(
      setDoc(doc(as(ANA), "appointments", "pedido-ana"), {
        patientId: ANA,
        professionalId: DRA,
        childId: "filha",
        status: "requested",
      })
    );
  });

  test("paciente NAO cria agendamento com clinica/pagamento nem para crianca alheia", async () => {
    await assertFails(
      setDoc(doc(as(ANA), "appointments", "forjado-1"), {
        patientId: ANA,
        professionalId: DRA,
        status: "requested",
        clinicId: CLIN,
      })
    );
    await assertFails(
      setDoc(doc(as(ANA), "appointments", "forjado-2"), {
        patientId: ANA,
        professionalId: DRA,
        status: "requested",
        paid: true,
      })
    );
    await assertFails(
      setDoc(doc(as(DRA), "appointments", "forjado-3"), {
        patientId: DRA,
        professionalId: DRA,
        childId: "filha",
        status: "requested",
      })
    );
  });

  test("change_log so de quem participa do agendamento", async () => {
    await assertSucceeds(
      setDoc(doc(as(ANA), "appointments", "consulta1", "change_log", "l1"), {
        actorUid: ANA,
        action: "cancelled",
      })
    );
    await assertFails(
      setDoc(doc(as(BRUNO), "appointments", "consulta1", "change_log", "l2"), {
        actorUid: BRUNO,
        action: "forjado",
      })
    );
  });

  test("responsavel vinculado le crescimento/vacinas, mas nao grava", async () => {
    await assertSucceeds(
      getDoc(doc(as(BRUNO), "users", ANA, "children", "filha", "growth_records", "m1"))
    );
    await assertFails(
      setDoc(
        doc(as(BRUNO), "users", ANA, "children", "filha", "growth_records", "m2"),
        { weightKg: 1 }
      )
    );
    await assertFails(
      updateDoc(
        doc(as(BRUNO), "users", ANA, "children", "filha", "vaccine_doses", "bcg-1"),
        { appliedAt: new Date() }
      )
    );
  });

  test("linked_children so e gravado pelo dono da crianca", async () => {
    await assertSucceeds(
      setDoc(doc(as(ANA), "users", BRUNO, "linked_children", "filha"), {
        guardianUid: BRUNO,
        childId: "filha",
        ownerId: ANA,
        status: "active",
      })
    );
    await assertFails(
      setDoc(doc(as(BRUNO), "users", ANA, "linked_children", "falsa"), {
        guardianUid: ANA,
        childId: "falsa",
        ownerId: BRUNO,
      })
    );
  });

  test("onboarding: conta nova escolhe ser profissional (sem verificacao)", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "uid_cadastro_novo"), {
        role: "parent",
        plan: "free",
        professionalVerified: false,
        xp: 0,
        streakDays: 0,
        onboardingDone: false,
      });
    });
    const eu = doc(as("uid_cadastro_novo"), "users", "uid_cadastro_novo");
    await assertFails(updateDoc(eu, { role: "admin", onboardingDone: true }));
    await assertFails(
      updateDoc(eu, { role: "professional", professionalVerified: true, onboardingDone: true })
    );
    await assertSucceeds(
      updateDoc(eu, {
        role: "professional",
        crm: "111111/SP",
        onboardingDone: true,
        professionalVerified: false,
      })
    );
    await assertFails(updateDoc(eu, { role: "parent" }));
  });

  test("campos de sequencia (streak) sao do servidor", async () => {
    await assertFails(updateDoc(doc(as(ANA), "users", ANA), { longestStreak: 999 }));
    await assertFails(updateDoc(doc(as(ANA), "users", ANA), { lastStreakDate: new Date() }));
  });

  test("CRM fica travado depois da verificacao", async () => {
    await assertFails(updateDoc(doc(as(DRA), "users", DRA), { crm: "000001/RJ" }));
    await assertSucceeds(updateDoc(doc(as(DRA), "users", DRA), { name: "Dra. Marta S." }));
    await assertSucceeds(updateDoc(doc(as(DR_NOVO), "users", DR_NOVO), { crm: "999998/SP" }));
    await assertSucceeds(updateDoc(doc(as(ADMIN), "users", DRA), { crm: "123457/SP" }));
  });

  test("evento de auditoria so leva clinicId de clinica da qual o autor e membro", async () => {
    const evento = (clinicId) => ({
      actorUid: DRA,
      action: "export",
      module: "finance",
      at: new Date().toISOString(),
      ...(clinicId ? { clinicId } : {}),
    });
    await assertFails(addDoc(collection(as(DRA), "security_audit_logs"), evento(CLIN)));
    await assertSucceeds(addDoc(collection(as(DRA), "security_audit_logs"), evento(null)));
    await assertSucceeds(
      addDoc(collection(as(FIN), "security_audit_logs"), { ...evento(CLIN), actorUid: FIN })
    );
  });
});
