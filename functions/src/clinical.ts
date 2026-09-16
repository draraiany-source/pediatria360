/**
 * Assistente clínico do prontuário.
 *
 * ## A linha de projeto que governa este arquivo
 *
 * O assistente trabalha sobre **o que o médico escreveu** e sobre **dados
 * estruturados** já registrados. Ele nunca recebe pixels de exame de imagem
 * para produzir achado diagnóstico.
 *
 * O motivo é técnico antes de ser regulatório: um modelo de linguagem não lê
 * radiografia, tomografia, ECG ou ecocardiograma. O que ele faz, se
 * solicitado, é produzir um texto com aparência de laudo. Num plantão de
 * madrugada esse texto é indistinguível de um laudo real e pode ser aceito.
 *
 * Somam-se a isso as exigências regulatórias: software que interpreta exame
 * para fim diagnóstico é dispositivo médico e tem trilha própria na ANVISA.
 *
 * O que este arquivo faz, e faz bem:
 *   - redige evolução a partir dos achados que o médico registrou
 *   - resume um atendimento ou uma linha do tempo de atendimentos
 *   - lista hipóteses diferenciais A CONSIDERAR, partindo da descrição clínica
 *   - aponta qual protocolo cadastrado se aplica ao caso
 *   - transcreve valores de laudo laboratorial em texto para campos estruturados
 *
 * Em todas as saídas, a decisão permanece do médico, e isso é dito na resposta.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

const REGION = "southamerica-east1";
const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const db = () => admin.firestore();

/** Tarefas permitidas. Lista fechada — não há modo livre. */
type ClinicalTask =
  | "draftProgressNote"
  | "summarizeEncounter"
  | "summarizeHistory"
  | "differentialConsiderations"
  | "matchProtocol"
  | "parseLabReport";

const ALLOWED_TASKS: ClinicalTask[] = [
  "draftProgressNote",
  "summarizeEncounter",
  "summarizeHistory",
  "differentialConsiderations",
  "matchProtocol",
  "parseLabReport",
];

/**
 * Termos que indicam pedido de laudo de imagem.
 *
 * Se aparecerem no texto livre enviado, a requisição é recusada com
 * explicação. Não é filtro de palavrão — é a barreira que impede o assistente
 * de ser usado para uma finalidade que ele não cumpre.
 */
const IMAGING_REQUEST = [
  /\b(laud|interpret|analis|avali)\w*\s+(o\s+|a\s+|esse\s+|este\s+|essa\s+)?(raio|rx|radiografi|tomografi|resson|ultrassom|usg|ecocardiogram|eco\b|ecg\b|eletrocardiogram|doppler|cintilografi|mamografi|densitometri)/i,
  /\b(o que (voce |vc )?(ve|acha|observa))\b.*\b(imagem|radiografi|tomografi|ecg|ultrassom)/i,
  /\bdescreva\s+(a\s+)?(imagem|radiografi|tomografi|ecg)/i,
];

function looksLikeImagingRequest(text: string): boolean {
  return IMAGING_REQUEST.some((re) => re.test(text));
}

const BASE_SYSTEM = `Você é um assistente de documentação clínica em um prontuário eletrônico pediátrico brasileiro. Escreve em português do Brasil, registro técnico.

QUEM LÊ VOCÊ
Um médico. Ele conhece a criança, examinou, e vai revisar e assinar o que você redigir. Escreva para um par, não para leigo.

O QUE VOCÊ FAZ
Organiza, redige e resume informação que o médico já registrou. Aponta o que ele pode ter deixado de considerar.

O QUE VOCÊ NÃO FAZ
- Não decide diagnóstico. Você lista hipóteses a considerar; quem conclui é o médico.
- Não indica medicamento nem dose por iniciativa própria. Se o médico prescreveu, você formata. Se ele perguntar "o que dou", devolva as classes terapêuticas que o protocolo cita e diga que a escolha e a dose são dele.
- Não interpreta exame de imagem, ECG, gasometria ou qualquer traçado. Você não tem essa capacidade. Se pedirem, diga isso com clareza e ofereça registrar o laudo do especialista.
- Não inventa achado. Se o registro do médico não menciona ausculta, você não escreve nada sobre ausculta.

REGRA DE OURO
Só use o que está no material fornecido. Nada de completar lacuna com o que "costuma ser". Um exame não descrito é um exame não realizado, e o texto deve deixar isso visível em vez de preencher.

FORMATO
Sem preâmbulo. Sem "aqui está". Comece pelo conteúdo.`;

const TASK_PROMPTS: Record<ClinicalTask, string> = {
  draftProgressNote: `TAREFA: redigir a evolução deste atendimento.

Estruture em: subjetivo (o que foi relatado), objetivo (achados de exame e sinais vitais), avaliação (correlação entre achados e hipóteses), conduta (o que foi decidido).

Use exclusivamente o que consta no material. Onde faltar informação, escreva "não registrado" em vez de omitir a linha — o vazio precisa ficar visível para o médico decidir se completa.

Máximo de 300 palavras.`,

  summarizeEncounter: `TAREFA: resumir este atendimento em um parágrafo denso, do tipo que se lê antes de entrar na sala do retorno.

Priorize: motivo, achado mais relevante, diagnóstico, conduta e o que precisa ser reavaliado.`,

  summarizeHistory: `TAREFA: sintetizar a linha do tempo de atendimentos.

Destaque padrões que só aparecem no conjunto: recorrências, evolução de peso e estatura, mudanças de conduta, exames pendentes. Termine com "pontos em aberto".

Máximo de 400 palavras.`,

  differentialConsiderations: `TAREFA: listar hipóteses diagnósticas a CONSIDERAR, a partir dos achados descritos.

Para cada hipótese: o que no quadro a sustenta, o que a enfraquece, e o que ajudaria a diferenciar.

Ordene por relevância clínica, começando pelo que não pode passar em branco — mesmo que improvável, o grave vem primeiro.

Encerre com: "Lista de apoio ao raciocínio. A conclusão diagnóstica é do médico assistente."

Máximo de 8 hipóteses.`,

  matchProtocol: `TAREFA: indicar quais dos protocolos fornecidos se aplicam a este caso e por quê.

Se nenhum se aplicar bem, diga isso — forçar um protocolo inadequado é pior que não indicar nenhum.

Cite cada protocolo pelo título exato.`,

  parseLabReport: `TAREFA: transcrever os resultados deste laudo laboratorial em JSON estruturado.

Isto é TRANSCRIÇÃO, não interpretação. Copie os valores como estão no laudo. Não comente, não classifique, não sugira significado.

Responda APENAS com um array JSON, sem cercas de markdown, no formato:
[{"analyte":"Hemoglobina","value":11.2,"unit":"g/dL","referenceLow":11.5,"referenceHigh":15.5}]

Campos sem valor no laudo: use null. Resultado textual (ex.: "Reagente") vai em "textValue" em vez de "value".`,
};

interface ClinicalAssistRequest {
  task: ClinicalTask;
  encounterId?: string;
  patientId?: string;
  freeText?: string;
}

/** Só médico verificado usa o assistente clínico. */
async function requireVerifiedProfessional(uid: string | undefined) {
  if (!uid) throw new HttpsError("unauthenticated", "Entre para continuar.");

  const doc = await db().collection("users").doc(uid).get();
  const user = doc.data() ?? {};

  const isPro = user.role === "professional" || user.role === "admin";
  if (!isPro || user.professionalVerified !== true) {
    throw new HttpsError(
      "permission-denied",
      "O assistente clínico é restrito a profissionais com registro verificado."
    );
  }
  return { uid, name: (user.name as string) ?? "" };
}

/** Monta o material de contexto a partir do que está registrado. */
async function buildContext(
  task: ClinicalTask,
  uid: string,
  encounterId?: string,
  patientId?: string
): Promise<string> {
  const blocks: string[] = [];

  if (encounterId) {
    const doc = await db().collection("encounters").doc(encounterId).get();
    if (!doc.exists) {
      throw new HttpsError("not-found", "Atendimento não encontrado.");
    }

    const e = doc.data() ?? {};

    // O assistente só enxerga atendimento do próprio profissional.
    if (e.professionalId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Este atendimento não é seu."
      );
    }

    const a = e.anamnesis ?? {};
    const v = e.vitals ?? {};
    const ex = e.exam ?? {};

    blocks.push(
      [
        "## ATENDIMENTO",
        `Tipo: ${e.type ?? "—"}`,
        e.patientAgeMonths != null
          ? `Idade do paciente: ${e.patientAgeMonths} meses`
          : "",
        "",
        "### Anamnese",
        `Queixa: ${a.chiefComplaint || "não registrada"}`,
        `HDA: ${a.historyOfPresentIllness || "não registrada"}`,
        a.pastMedicalHistory ? `Antecedentes: ${a.pastMedicalHistory}` : "",
        a.gestationalHistory ? `Gestação: ${a.gestationalHistory}` : "",
        a.birthHistory ? `Nascimento: ${a.birthHistory}` : "",
        a.developmentHistory ? `DNPM: ${a.developmentHistory}` : "",
        a.feedingHistory ? `Alimentação: ${a.feedingHistory}` : "",
        (a.allergies ?? []).length
          ? `Alergias: ${(a.allergies as string[]).join(", ")}`
          : "Alergias: nenhuma registrada",
        (a.currentMedications ?? []).length
          ? `Medicações em uso: ${(a.currentMedications as string[]).join(", ")}`
          : "",
        a.familyHistory ? `História familiar: ${a.familyHistory}` : "",
        "",
        "### Sinais vitais",
        Object.entries(v)
          .filter(([, val]) => val != null)
          .map(([k, val]) => `${k}: ${val}`)
          .join("; ") || "não aferidos",
        "",
        "### Exame físico",
        Object.entries((ex.findings ?? {}) as Record<string, string>)
          .map(([system, finding]) => `${system}: ${finding}`)
          .join("\n") || "não registrado",
        "",
        "### Diagnósticos registrados",
        ((e.diagnoses ?? []) as { code: string; description: string; certainty: string }[])
          .map((d) => `${d.code} — ${d.description} (${d.certainty})`)
          .join("\n") || "nenhum",
        "",
        e.assessment ? `### Avaliação\n${e.assessment}` : "",
        e.plan ? `### Conduta\n${e.plan}` : "",
      ]
        .filter(Boolean)
        .join("\n")
    );

    // Exames laboratoriais recentes, como valores — nunca como imagem.
    const labs = await db()
      .collection("lab_results")
      .where("patientId", "==", e.patientId)
      .orderBy("collectedAt", "desc")
      .limit(30)
      .get();

    if (!labs.empty) {
      blocks.push(
        "## EXAMES LABORATORIAIS RECENTES\n" +
          labs.docs
            .map((d) => {
              const l = d.data();
              const ref =
                l.referenceLow != null || l.referenceHigh != null
                  ? ` [ref ${l.referenceLow ?? ""}–${l.referenceHigh ?? ""}]`
                  : "";
              return `${l.analyte}: ${l.value ?? l.textValue ?? "—"} ${l.unit ?? ""}${ref}`;
            })
            .join("\n")
      );
    }
  }

  // Histórico: só para a tarefa que precisa dele.
  if (task === "summarizeHistory" && patientId) {
    const previous = await db()
      .collection("encounters")
      .where("patientId", "==", patientId)
      .where("status", "in", ["signed", "amended"])
      .orderBy("startedAt", "desc")
      .limit(15)
      .get();

    blocks.push(
      "## ATENDIMENTOS ANTERIORES\n" +
        previous.docs
          .map((d) => {
            const e = d.data();
            const date = (e.startedAt as admin.firestore.Timestamp)
              ?.toDate()
              .toLocaleDateString("pt-BR");
            const dx = ((e.diagnoses ?? []) as { description: string }[])
              .map((x) => x.description)
              .join(", ");
            return `${date} — ${e.anamnesis?.chiefComplaint ?? "—"} | Dx: ${dx || "—"} | Conduta: ${e.plan ?? "—"}`;
          })
          .join("\n")
    );
  }

  // Protocolos, para a tarefa de correspondência.
  if (task === "matchProtocol" || task === "differentialConsiderations") {
    const protocols = await db()
      .collection("articles")
      .where("published", "==", true)
      .where("type", "==", "protocol")
      .limit(25)
      .get();

    if (!protocols.empty) {
      blocks.push(
        "## PROTOCOLOS CADASTRADOS NA PLATAFORMA\n" +
          protocols.docs
            .map((d) => {
              const p = d.data();
              const sections = ((p.sections ?? []) as { title: string; body: string }[])
                .map((s) => `${s.title}: ${s.body}`)
                .join("\n")
                .slice(0, 1200);
              return `### ${p.title}\n${sections}`;
            })
            .join("\n\n")
      );
    }
  }

  return blocks.join("\n\n---\n\n");
}

const CLINICAL_ASSIST_DAILY_LIMIT = 300;

/**
 * Cota diária compartilhada pelas duas funções deste arquivo que chamam a
 * API de IA (`clinicalAssist` e `parseLabText`) — do ponto de vista do
 * profissional, é "o assistente clínico", uma única ferramenta, um teto só.
 * Duas cotas separadas de 300 dobraria a exposição de custo sem necessidade.
 *
 * Lança `resource-exhausted` se o teto já foi atingido; senão devolve a
 * referência do documento, para `consumeClinicalQuota` incrementar depois
 * que a chamada à IA realmente for bem-sucedida.
 */
async function checkClinicalQuota(
  uid: string
): Promise<admin.firestore.DocumentReference> {
  const ref = db()
    .collection("users")
    .doc(uid)
    .collection("clinical_assist_usage")
    .doc(new Date().toISOString().slice(0, 10));

  const snap = await ref.get();
  const used = (snap.data()?.count as number) ?? 0;

  if (used >= CLINICAL_ASSIST_DAILY_LIMIT) {
    throw new HttpsError(
      "resource-exhausted",
      `Limite de ${CLINICAL_ASSIST_DAILY_LIMIT} usos do assistente hoje ` +
        "atingido. Renova amanhã."
    );
  }

  return ref;
}

/** Só chamar depois que a resposta da IA já tiver sido obtida com sucesso —
 * uma chamada que falhou por rede ou instabilidade não deveria custar do
 * limite do profissional. */
async function consumeClinicalQuota(
  ref: admin.firestore.DocumentReference
): Promise<void> {
  await ref.set(
    {
      count: admin.firestore.FieldValue.increment(1),
      limit: CLINICAL_ASSIST_DAILY_LIMIT,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

export const clinicalAssist = onCall(
  { region: REGION, secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);

    // aiChat (o chat dos responsáveis) já tinha proteção de custo; este
    // assistente — que também chama o modelo, com o mesmo custo por
    // chamada — não tinha nenhuma. Um cliente com bug ou um profissional
    // clicando em loop rodaria a fatura da API sem limite algum.
    const clinicalUsageRef = await checkClinicalQuota(actor.uid);

    const { task, encounterId, patientId, freeText } =
      request.data as ClinicalAssistRequest;

    if (!ALLOWED_TASKS.includes(task)) {
      throw new HttpsError("invalid-argument", "Tarefa não reconhecida.");
    }

    // Barreira contra uso para laudo de imagem.
    if (freeText && looksLikeImagingRequest(freeText)) {
      return {
        refused: true,
        text:
          "Não interpreto exames de imagem, ECG ou traçados — não tenho essa " +
          "capacidade, e um texto meu com aparência de laudo seria inventado.\n\n" +
          "O que posso fazer: registrar o laudo do radiologista ou " +
          "cardiologista como texto no atendimento, e usá-lo como contexto " +
          "para resumo e raciocínio clínico.",
      };
    }

    const context = await buildContext(task, actor.uid, encounterId, patientId);

    if (!context && !freeText) {
      throw new HttpsError(
        "failed-precondition",
        "Registre o atendimento antes de acionar o assistente."
      );
    }

    const userContent = [
      TASK_PROMPTS[task],
      "",
      "=== MATERIAL ===",
      context || "(sem registro no prontuário)",
      freeText ? `\n=== OBSERVAÇÃO DO MÉDICO ===\n${freeText.slice(0, 4000)}` : "",
    ].join("\n");

    let text: string;

    try {
      const response = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": ANTHROPIC_API_KEY.value(),
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: "claude-sonnet-4-5",
          max_tokens: 2000,
          // Temperatura baixa: em documentação clínica, variação criativa é
          // defeito, não recurso.
          temperature: 0.2,
          system: BASE_SYSTEM,
          messages: [{ role: "user", content: userContent }],
        }),
      });

      if (!response.ok) {
        logger.error("Falha na API do assistente clínico", {
          status: response.status,
        });
        throw new HttpsError("unavailable", "Assistente indisponível agora.");
      }

      const data = (await response.json()) as {
        content: { type: string; text?: string }[];
      };

      text = data.content
        .filter((c) => c.type === "text")
        .map((c) => c.text ?? "")
        .join("\n")
        .trim();
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("Erro no assistente clínico", error);
      throw new HttpsError("internal", "Não foi possível gerar o texto.");
    }

    // Registro de uso. Texto gerado por IA que entra em prontuário precisa ser
    // rastreável: quem pediu, para qual atendimento, quando.
    await db().collection("ai_clinical_log").add({
      task,
      encounterId: encounterId ?? null,
      patientId: patientId ?? null,
      actorUid: actor.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      outputLength: text.length,
    });

    // Só consome cota depois do sucesso.
    await consumeClinicalQuota(clinicalUsageRef);

    return {
      refused: false,
      text,
      task,
      // A tela exibe isto junto ao texto, e o texto entra no prontuário como
      // rascunho — nunca assinado automaticamente.
      disclaimer:
        "Rascunho gerado por IA a partir do que você registrou. Revise antes " +
        "de assinar: a responsabilidade pelo conteúdo do prontuário é sua.",
    };
  }
);

/**
 * Transcreve um laudo laboratorial em texto para valores estruturados.
 *
 * Recebe o TEXTO já extraído do PDF (por OCR no cliente ou pelo laboratório),
 * não a imagem. A saída é conferida pelo médico antes de virar registro.
 *
 * ## Sem tela na versão 1.0 — decisão, não esquecimento
 *
 * A Function está pronta e com cota (`checkClinicalQuota`), mas não há
 * import screen no app: nenhuma tela deixa o profissional colar o texto do
 * laudo, ver o resultado estruturado, e confirmar antes de salvar. Construir
 * essa tela exige decisões de UX que não foram tomadas ainda — como mostrar
 * cada valor pra conferência, o que acontece se a IA não conseguir
 * estruturar, se cabe captura de imagem com OCR local. `image_picker` foi
 * removido do pubspec por não ter, hoje, nenhum consumidor real: reintroduza
 * junto com a tela, não antes dela.
 */
export const parseLabText = onCall(
  { region: REGION, secrets: [ANTHROPIC_API_KEY], timeoutSeconds: 90 },
  async (request) => {
    const actor = await requireVerifiedProfessional(request.auth?.uid);

    const labUsageRef = await checkClinicalQuota(actor.uid);

    const { text } = request.data as { text: string };

    if (!text || text.trim().length < 20) {
      throw new HttpsError("invalid-argument", "Texto do laudo vazio.");
    }
    if (text.length > 20000) {
      throw new HttpsError("invalid-argument", "Laudo muito longo.");
    }

    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY.value(),
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-5",
        max_tokens: 3000,
        temperature: 0,
        system: BASE_SYSTEM,
        messages: [
          {
            role: "user",
            content: `${TASK_PROMPTS.parseLabReport}\n\n=== LAUDO ===\n${text}`,
          },
        ],
      }),
    });

    if (!response.ok) {
      throw new HttpsError("unavailable", "Serviço indisponível.");
    }

    const data = (await response.json()) as {
      content: { type: string; text?: string }[];
    };

    const raw = data.content
      .filter((c) => c.type === "text")
      .map((c) => c.text ?? "")
      .join("")
      .replace(/```json|```/g, "")
      .trim();

    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      logger.warn("Transcrição de laudo não retornou JSON válido");
      throw new HttpsError(
        "internal",
        "Não consegui estruturar este laudo. Registre os valores manualmente."
      );
    }

    if (!Array.isArray(parsed)) {
      throw new HttpsError("internal", "Formato inesperado.");
    }

    logger.info("Laudo transcrito", {
      actor: actor.uid,
      items: parsed.length,
    });

    await consumeClinicalQuota(labUsageRef);

    return {
      results: parsed,
      disclaimer:
        "Transcrição automática. Confira cada valor contra o laudo original " +
        "antes de salvar.",
    };
  }
);
