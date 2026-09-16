/**
 * Popula o Firestore com conteúdo inicial para desenvolvimento.
 *
 * Uso:
 *   cd tool/seed
 *   npm install firebase-admin
 *   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json node seed.js
 *
 * Ou contra o emulador:
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 node seed.js
 *
 * ## Sobre o conteúdo médico daqui
 *
 * Os artigos abaixo são **exemplos de estrutura**, escritos em linguagem
 * conservadora e sem posologia. Servem para a tela ter o que renderizar e para
 * a busca ter o que indexar. Antes de publicar, substitua por conteúdo escrito
 * e revisado por pediatra, preenchendo `reviewedBy` — a tela sinaliza ao leitor
 * quando esse campo está vazio.
 */

const admin = require("firebase-admin");

admin.initializeApp({
  projectId: process.env.GCLOUD_PROJECT || "pediatria360",
});

const db = admin.firestore();

/** Normaliza igual ao app e às Functions. */
function normalize(input) {
  return input
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function searchTerms(...parts) {
  return Array.from(
    new Set(normalize(parts.join(" ")).split(" ").filter((t) => t.length >= 3))
  ).slice(0, 200);
}

// ---------------------------------------------------------------- Artigos

const articles = [
  {
    id: "febre-quando-procurar",
    title: "Febre na criança: o que observar e quando procurar atendimento",
    summary:
      "A febre é uma resposta do corpo, não uma doença. O que importa não é o número no termômetro, e sim como a criança está.",
    type: "protocol",
    audience: "everyone",
    category: "febre",
    readMinutes: 5,
    author: "Equipe Pediatria 360",
    reviewedBy: null,
    published: true,
    ageRangeMonths: [0, 216],
    tags: ["febre", "temperatura", "infeccao"],
    sections: [
      {
        title: "Procure atendimento imediatamente se",
        kind: "redFlag",
        body:
          "• Bebê com menos de 3 meses e qualquer febre\n" +
          "• Criança muito prostrada, difícil de acordar ou que não interage\n" +
          "• Manchas roxas na pele que não somem ao pressionar\n" +
          "• Dificuldade para respirar, gemência ou afundamento entre as costelas\n" +
          "• Convulsão\n" +
          "• Rigidez de nuca ou dor de cabeça intensa\n" +
          "• Febre há mais de 3 dias sem melhora\n" +
          "• Sinais de desidratação: boca seca, choro sem lágrima, fralda seca por muitas horas",
      },
      {
        title: "O que é febre",
        kind: "text",
        body:
          "Considera-se febre a temperatura axilar a partir de 37,8 °C. É um mecanismo de defesa: o corpo eleva a temperatura para dificultar a multiplicação de vírus e bactérias.\n\n" +
          "O valor da temperatura não indica a gravidade. Uma criança com 39 °C brincando e bebendo água costuma preocupar menos que uma com 38 °C prostrada e recusando líquidos. Observe o comportamento, não só o termômetro.",
      },
      {
        title: "O que fazer em casa",
        kind: "steps",
        body:
          "Ofereça líquidos com frequência, em pequenas quantidades\n" +
          "Deixe a criança com roupas leves, sem agasalhar demais\n" +
          "Mantenha o ambiente arejado e em temperatura confortável\n" +
          "Deixe que descanse; não force alimentação, mas mantenha a hidratação\n" +
          "Anote os horários e valores da temperatura para mostrar ao pediatra",
      },
      {
        title: "Sobre medicamentos",
        kind: "text",
        body:
          "A escolha do antitérmico, a dose e o intervalo dependem do peso, da idade e do histórico da criança. Converse com o pediatra ou o farmacêutico antes de medicar.\n\n" +
          "Nunca ofereça medicamento sobrando de outra ocasião nem dose calculada por idade — o cálculo é por peso, e a diferença tem consequência.",
      },
      {
        title: "Referências",
        kind: "reference",
        body:
          "Substitua por referências verificadas da Sociedade Brasileira de Pediatria e do Ministério da Saúde antes de publicar.",
      },
    ],
  },
  {
    id: "sono-seguro-bebe",
    title: "Sono seguro no primeiro ano",
    summary:
      "Como reduzir o risco de morte súbita do lactente com medidas simples de posicionamento e ambiente.",
    type: "article",
    audience: "parents",
    category: "sono",
    readMinutes: 4,
    author: "Equipe Pediatria 360",
    reviewedBy: null,
    published: true,
    ageRangeMonths: [0, 12],
    tags: ["sono", "berco", "morte subita"],
    sections: [
      {
        title: "As regras que mais importam",
        kind: "steps",
        body:
          "Coloque o bebê para dormir de barriga para cima, em todas as sonecas\n" +
          "Use colchão firme, sem travesseiro, protetor de berço ou bichinhos\n" +
          "Mantenha o berço no quarto dos pais nos primeiros meses, mas em superfície separada\n" +
          "Não deixe cobertores soltos; prefira saco de dormir adequado ao tamanho\n" +
          "Evite superaquecer o ambiente",
      },
      {
        title: "Procure orientação se",
        kind: "redFlag",
        body:
          "O bebê apresentar pausas na respiração, ficar arroxeado durante o sono ou tiver dificuldade respiratória. Nesses casos, procure atendimento.",
      },
    ],
  },
  {
    id: "introducao-alimentar",
    title: "Introdução alimentar: por onde começar",
    summary:
      "Aos 6 meses o leite deixa de ser suficiente sozinho. O começo é mais sobre experiência do que sobre quantidade.",
    type: "article",
    audience: "parents",
    category: "nutricao",
    readMinutes: 6,
    author: "Equipe Pediatria 360",
    reviewedBy: null,
    published: true,
    ageRangeMonths: [4, 24],
    tags: ["alimentacao", "papinha", "amamentacao", "seis meses"],
    sections: [
      {
        title: "Quando começar",
        kind: "text",
        body:
          "A recomendação é iniciar aos 6 meses, mantendo o leite materno. Antes disso, o sistema digestivo e o controle de cabeça e tronco geralmente ainda não estão prontos.\n\n" +
          "Sinais de que a criança está pronta: senta com apoio, sustenta a cabeça firme, demonstra interesse pela comida e perdeu o reflexo de empurrar objetos com a língua.",
      },
      {
        title: "Nas primeiras semanas",
        kind: "steps",
        body:
          "Ofereça um alimento novo por vez, por dois a três dias, para identificar reações\n" +
          "Amasse com o garfo em vez de bater no liquidificador: a textura ensina a mastigar\n" +
          "Não adicione açúcar, sal ou temperos industrializados\n" +
          "Ofereça água em copo nas refeições\n" +
          "Espere recusa: uma criança pode precisar ver o alimento muitas vezes antes de aceitar",
      },
    ],
  },
];

// --------------------------------------------------------------- Medalhas

const badges = [
  {
    id: "primeira-medicao",
    name: "Primeiro registro",
    description: "Você registrou a primeira medição de crescimento.",
    icon: "growth",
    tier: "bronze",
    requirement: "Registrar uma medição",
  },
  {
    id: "caderneta-em-dia",
    name: "Caderneta em dia",
    description: "Todas as vacinas previstas até agora estão aplicadas.",
    icon: "vaccine",
    tier: "gold",
    requirement: "Nenhuma vacina em atraso",
  },
  {
    id: "sete-dias",
    name: "Uma semana",
    description: "Sete dias seguidos acompanhando.",
    icon: "fire",
    tier: "bronze",
    requirement: "Sequência de 7 dias",
  },
  {
    id: "trinta-dias",
    name: "Um mês inteiro",
    description: "Trinta dias de acompanhamento.",
    icon: "fire",
    tier: "silver",
    requirement: "Sequência de 30 dias",
  },
  {
    id: "leitor",
    name: "Leitor atento",
    description: "Dez artigos lidos na biblioteca.",
    icon: "book",
    tier: "bronze",
    requirement: "Ler 10 artigos",
  },
  {
    id: "primeiro-curso",
    name: "Primeiro curso",
    description: "Você concluiu um curso completo.",
    icon: "school",
    tier: "silver",
    requirement: "Concluir um curso",
  },
];

// ---------------------------------------------------------------- Cupons

const coupons = [
  {
    id: "BEMVINDO10",
    active: true,
    type: "percent",
    value: 10,
    minSubtotalCents: 5000,
    maxUses: 1000,
    usedCount: 0,
  },
];

// ---------------------------------------------------------------- Produtos

const products = [
  {
    id: "vitamina-d-gotas",
    name: "Vitamina D 400 UI · gotas",
    description:
      "Suplementação de vitamina D em gotas. A suplementação de rotina no primeiro ano é recomendada, mas a dose deve ser confirmada com o pediatra.",
    priceCents: 3990,
    compareAtPriceCents: 4990,
    category: "supplement",
    brand: "Exemplo",
    stock: 50,
    published: true,
    requiresPrescription: false,
    ageRangeMonths: [0, 24],
    tags: ["vitamina d", "suplemento"],
  },
  {
    id: "termometro-digital",
    name: "Termômetro digital infantil",
    description: "Leitura em 10 segundos, ponta flexível, à prova d'água.",
    priceCents: 4590,
    category: "safety",
    brand: "Exemplo",
    stock: 30,
    published: true,
    tags: ["termometro", "febre"],
  },
];

// ------------------------------------------------------------------ Seed

async function seed() {
  console.log("Populando Firestore...\n");

  const batch = db.batch();

  for (const article of articles) {
    const { id, ...data } = article;
    batch.set(db.collection("articles").doc(id), {
      ...data,
      searchTerms: searchTerms(
        data.title,
        data.summary,
        data.tags.join(" "),
        data.category,
        data.sections.map((s) => s.title).join(" ")
      ),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  artigo: ${data.title}`);
  }

  for (const badge of badges) {
    const { id, ...data } = badge;
    batch.set(db.collection("badges").doc(id), data);
  }
  console.log(`  ${badges.length} medalhas`);

  for (const coupon of coupons) {
    const { id, ...data } = coupon;
    batch.set(db.collection("coupons").doc(id), {
      ...data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  console.log(`  ${coupons.length} cupom`);

  for (const product of products) {
    const { id, ...data } = product;
    batch.set(db.collection("products").doc(id), {
      ...data,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  console.log(`  ${products.length} produtos`);

  await batch.commit();

  console.log("\nPronto.");
  console.log(
    "\nPara virar admin, rode no console do Firebase ou aqui:\n" +
      '  db.collection("users").doc("SEU_UID").update({ role: "admin" })\n'
  );
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Falhou:", error);
    process.exit(1);
  });
