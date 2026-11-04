import { createHmac } from "crypto";
import {
  buildReminderTemplate,
  dueReminderOffset,
  maskPhone,
  normalizeBrazilPhone,
  parseWebhook,
  sendWhatsAppTemplate,
  verifySignature,
  verifyWebhookChallenge,
} from "./whatsapp";

const params = {
  to: "5511900000001",
  reminderId: "r1",
  guardianFirstName: "Responsável Exemplo",
  childFirstName: "Luna Exemplo Souza",
  clinicName: "Consultório Exemplo",
  whenLabel: "qui, 01/10 às 09:30",
  teleconsulta: false,
};

describe("modelo de lembrete", () => {
  test("usa o modelo aprovado, só primeiros nomes e três botões", () => {
    const p = buildReminderTemplate(params);
    expect(p.template.name).toBe("lembrete_consulta_v1");
    expect(p.template.language.code).toBe("pt_BR");
    const body = p.template.components[0] as {
      parameters: Array<{ text: string }>;
    };
    expect(body.parameters.map((x) => x.text)).toEqual([
      "Responsável",
      "Luna",
      "Consultório Exemplo",
      "qui, 01/10 às 09:30",
      "presencial",
    ]);
    const payloads = p.template.components
      .slice(1)
      .map((c) => (c as { parameters: Array<{ payload: string }> }).parameters[0].payload);
    expect(payloads).toEqual(["r1:confirmar", "r1:reagendar", "r1:cancelar"]);
    expect(JSON.stringify(p)).not.toMatch(/Souza|febre|exame|diagn/i);
  });

  test("telefone", () => {
    expect(normalizeBrazilPhone("+55 (11) 90000-0001")).toBe("5511900000001");
    expect(normalizeBrazilPhone("90000-0001")).toBeNull();
    expect(maskPhone("5511900000001")).toBe("•••• 0001");
  });
});

describe("envio", () => {
  test("sem credenciais não chama a API", async () => {
    const fetchImpl = jest.fn();
    const r = await sendWhatsAppTemplate(buildReminderTemplate(params), {
      phoneNumberId: "",
      accessToken: "",
      fetchImpl,
    });
    expect(r.ok).toBe(false);
    expect(fetchImpl).not.toHaveBeenCalled();
  });

  test("sucesso devolve o id da mensagem", async () => {
    const fetchImpl = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ messages: [{ id: "wamid.X" }] }),
    });
    const r = await sendWhatsAppTemplate(buildReminderTemplate(params), {
      phoneNumberId: "123",
      accessToken: "token-de-teste",
      fetchImpl,
    });
    expect(r).toEqual({ ok: true, messageId: "wamid.X" });
    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe("https://graph.facebook.com/v21.0/123/messages");
    expect(init.headers.Authorization).toBe("Bearer token-de-teste");
  });

  test("erro da API vira falha (para contato manual)", async () => {
    const fetchImpl = jest.fn().mockResolvedValue({
      ok: false,
      status: 400,
      json: async () => ({ error: { code: 131026, message: "Undeliverable" } }),
    });
    const r = await sendWhatsAppTemplate(buildReminderTemplate(params), {
      phoneNumberId: "123",
      accessToken: "t",
      fetchImpl,
    });
    expect(r).toEqual({ ok: false, errorCode: 131026, errorMessage: "Undeliverable" });
  });
});

describe("webhook", () => {
  test("desafio de verificação", () => {
    const q = { "hub.mode": "subscribe", "hub.verify_token": "abc", "hub.challenge": "42" };
    expect(verifyWebhookChallenge(q, "abc")).toBe("42");
    expect(verifyWebhookChallenge(q, "outro")).toBeNull();
    expect(verifyWebhookChallenge(q, "")).toBeNull();
  });

  test("assinatura HMAC", () => {
    const raw = '{"entry":[]}';
    const sig = "sha256=" + createHmac("sha256", "segredo").update(raw).digest("hex");
    expect(verifySignature(raw, sig, "segredo")).toBe(true);
    expect(verifySignature(raw, sig, "errado")).toBe(false);
    expect(verifySignature(raw, undefined, "segredo")).toBe(false);
  });

  test("status e respostas", () => {
    const body = {
      entry: [
        {
          changes: [
            {
              value: {
                statuses: [
                  { id: "wamid.1", status: "delivered", timestamp: "1790000000", recipient_id: "5511900000001" },
                  {
                    id: "wamid.2",
                    status: "failed",
                    timestamp: "1790000100",
                    recipient_id: "5511900000003",
                    errors: [{ code: 131026, title: "Message undeliverable" }],
                  },
                ],
                messages: [
                  {
                    from: "5511900000001",
                    timestamp: "1790000200",
                    type: "button",
                    context: { id: "wamid.1" },
                    button: { payload: "r1:reagendar", text: "Reagendar" },
                  },
                  { from: "5511900000001", timestamp: "1790000300", type: "text", text: { body: "oi" } },
                ],
              },
            },
          ],
        },
      ],
    };
    const { statuses, replies } = parseWebhook(body);
    expect(statuses.map((s) => s.status)).toEqual(["delivered", "failed"]);
    expect(statuses[1].errorCode).toBe(131026);
    expect(statuses[0].recipient).toBe("•••• 0001");
    expect(replies).toHaveLength(1);
    expect(replies[0]).toMatchObject({ reminderId: "r1", reply: "reagendar", contextMessageId: "wamid.1" });
  });
});

describe("quando enviar", () => {
  const start = new Date("2026-10-01T09:30:00-03:00");
  test("envia só o mais próximo quando vários venceram", () => {
    expect(dueReminderOffset(start, [48, 24, 2], [], new Date("2026-09-30T20:00:00-03:00"))).toBe(24);
    expect(dueReminderOffset(start, [48, 24, 2], [48, 24], new Date("2026-09-30T20:00:00-03:00"))).toBeNull();
    expect(dueReminderOffset(start, [2], [], new Date("2026-10-01T10:00:00-03:00"))).toBeNull();
  });
});
