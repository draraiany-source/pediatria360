"""Auditoria de seguranca do Pediatria 360.

Verifica mecanicamente o que costuma passar despercebido em revisao manual:

  1. Toda collection escrita pelo app tem regra declarada
  2. Toda Cloud Function verifica autenticacao
  3. Funcoes que alteram dado de outro usuario verificam papel
  4. Campos controlados pelo servidor estao bloqueados nas regras
  5. Nenhum segredo esta no codigo do cliente
  6. Dado clinico nao e legivel por quem nao deveria

Nao substitui revisao humana nem pentest. Encontra a classe de erro que
aparece quando se adiciona uma collection e se esquece da regra — que e
exatamente como dado de saude vaza.

Uso: python3 tool/security_audit.py
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

findings = []


def finding(severity, title, detail):
    findings.append((severity, title, detail))


def read(path):
    full = os.path.join(ROOT, path)
    return open(full, encoding="utf-8").read() if os.path.exists(full) else ""


rules = read("firestore.rules")
storage_rules = read("storage.rules")


def dart_sources():
    for root, _, files in os.walk(os.path.join(ROOT, "lib")):
        for f in files:
            if f.endswith(".dart"):
                yield os.path.join(root, f)


def ts_sources():
    base = os.path.join(ROOT, "functions", "src")
    if not os.path.isdir(base):
        return
    for f in os.listdir(base):
        if f.endswith(".ts"):
            yield os.path.join(base, f)


# ---------------------------------------------------------------------------
# 1. Collections acessadas pelo app x regras declaradas
# ---------------------------------------------------------------------------

accessed = set()
for path in dart_sources():
    src = open(path, encoding="utf-8").read()
    for m in re.finditer(r"\.collection\(\s*'([a-z_]+)'", src):
        accessed.add(m.group(1))
    # Caminhos vindos de FirestorePaths
    for m in re.finditer(r"static const String \w+ = '([a-z_]+)'", src):
        if "firestore_paths" in path:
            accessed.add(m.group(1))

declared = set(re.findall(r"match /([a-z_]+)/\{", rules))
# Subcollections tambem contam
declared |= set(re.findall(r"match /([a-z_]+)/\{\w+\}\s*\{", rules))

missing_rules = accessed - declared - {"users"}  # users tem regra propria

if missing_rules:
    finding(
        "ALTA",
        "Collection sem regra declarada",
        "O app acessa mas firestore.rules nao declara: "
        + ", ".join(sorted(missing_rules))
        + ". Cai no fallback fechado — o app quebra, mas indica descuido.",
    )

# ---------------------------------------------------------------------------
# 2. Fallback fechado
# ---------------------------------------------------------------------------

if "match /{document=**}" not in rules:
    finding(
        "CRITICA",
        "Sem fallback fechado",
        "Uma collection nova nasce publica em vez de nascer fechada.",
    )
elif not re.search(
    r"match /\{document=\*\*\}\s*\{\s*allow read, write: if false;", rules
):
    finding(
        "CRITICA",
        "Fallback nao esta fechado",
        "O padrao final deve ser `allow read, write: if false;`.",
    )

# ---------------------------------------------------------------------------
# 3. Autenticacao em toda Cloud Function
# ---------------------------------------------------------------------------

for path in ts_sources():
    src = open(path, encoding="utf-8").read()
    name = os.path.basename(path)

    for m in re.finditer(
        r"export const (\w+) = onCall\((.*?)async \(request\) => \{|"
        r"export const (\w+) = onCall\((.*?)async \(request\) => \{",
        src,
        re.DOTALL,
    ):
        fn = m.group(1) or m.group(3)
        if not fn:
            continue

        # Corpo da funcao ate o proximo export
        start = m.end()
        nxt = src.find("\nexport const", start)
        body = src[start : nxt if nxt > 0 else len(src)]

        checks_auth = (
            "request.auth?.uid" in body
            or "requireAdmin" in body
            or "requireVerifiedProfessional" in body
        )

        # verifyDocument e publica de proposito: e a farmacia conferindo.
        if not checks_auth and fn != "verifyDocument":
            finding(
                "CRITICA",
                f"Function sem verificacao de autenticacao: {fn}",
                f"{name} — qualquer pessoa com a URL pode chamar.",
            )

# ---------------------------------------------------------------------------
# 4. Campos controlados pelo servidor
# ---------------------------------------------------------------------------

server_only = ["plan", "xp", "role", "professionalVerified"]
for field in server_only:
    if f"'{field}'" not in rules:
        finding(
            "ALTA",
            f"Campo de servidor nao protegido: {field}",
            "O cliente pode gravar diretamente, permitindo escalada de "
            "privilegio ou fraude.",
        )

# ---------------------------------------------------------------------------
# 5. Segredos no cliente
# ---------------------------------------------------------------------------

secret_patterns = [
    (r"sk-ant-[A-Za-z0-9\-_]{20,}", "chave da API de IA"),
    (r"AIza[0-9A-Za-z\-_]{35}", "chave do Google (fora de firebase_options)"),
    (r"['\"][0-9a-f]{32,}['\"]\s*;\s*//\s*(api|key|secret)", "segredo em hexadecimal"),
    (r"AccessKey['\"]?\s*[:=]\s*['\"][A-Za-z0-9\-]{20,}", "chave do Bunny"),
]

for path in dart_sources():
    src = open(path, encoding="utf-8").read()
    rel = os.path.relpath(path, ROOT)

    for pattern, label in secret_patterns:
        for m in re.finditer(pattern, src):
            # firebase_options.dart tem chaves publicas de propriedade — sao
            # identificadores de projeto, nao segredos.
            if "firebase_options" in rel:
                continue
            line = src[: m.start()].count("\n") + 1
            finding(
                "CRITICA",
                f"Possivel segredo no cliente: {label}",
                f"{rel}:{line}",
            )

# ---------------------------------------------------------------------------
# 6. Dado clinico: quem pode ler
# ---------------------------------------------------------------------------

clinical_collections = {
    "encounters": "prontuario",
    "clinical_documents": "receitas e atestados",
    "prescriptions": "prescricoes",
    "lab_results": "exames",
}

for collection, label in clinical_collections.items():
    block = re.search(
        r"match /" + collection + r"/\{[^}]+\}\s*\{(.*?)\n    \}",
        rules,
        re.DOTALL,
    )
    if not block:
        continue

    body = block.group(1)

    # Admin lendo prontuario e o erro classico: "a equipe precisa dar
    # suporte". Dado clinico de crianca nao e dado operacional.
    if "isAdmin()" in body and "allow read" in body:
        read_line = re.search(r"allow read:.*?;", body, re.DOTALL)
        if read_line and "isAdmin()" in read_line.group(0):
            finding(
                "MEDIA",
                f"Admin pode ler {label}",
                f"match /{collection}/ permite leitura por admin. "
                "Considere se a equipe precisa mesmo desse acesso.",
            )

# ---------------------------------------------------------------------------
# 7. Prontuario nao pode ser apagado
# ---------------------------------------------------------------------------

encounters_block = re.search(
    r"match /encounters/\{[^}]+\}\s*\{(.*?)\n    \}", rules, re.DOTALL
)
if encounters_block and "allow delete: if false" not in encounters_block.group(1):
    finding(
        "ALTA",
        "Prontuario pode ser apagado",
        "A guarda por 20 anos (CFM 1.821/2007) exige `allow delete: if false`.",
    )

# ---------------------------------------------------------------------------
# 8. Storage: dado de menor nao pode ser publico
# ---------------------------------------------------------------------------

if storage_rules:
    user_block = re.search(
        r"match /users/\{uid\}/\{[^}]+\}\s*\{(.*?)\}", storage_rules, re.DOTALL
    )
    if user_block and "if true" in user_block.group(1):
        finding(
            "CRITICA",
            "Arquivos de usuario publicos",
            "Fotos de criancas e comprovantes de vacina sao dado sensivel "
            "de menor.",
        )

# ---------------------------------------------------------------------------
# 9. LGPD: caminhos para exercer os direitos
# ---------------------------------------------------------------------------

privacy = read("functions/src/privacy.ts")
lgpd_rights = {
    "exportUserData": "Art. 18 §V — portabilidade",
    "requestDataDeletion": "Art. 18 §VI — eliminacao",
    "revokeConsent": "Art. 18 §IX — revogacao",
    "recordConsent": "Art. 14 — consentimento de crianca",
}

for fn, article in lgpd_rights.items():
    if f"export const {fn}" not in privacy:
        finding("ALTA", f"Direito da LGPD sem implementacao: {article}", f"Falta {fn}.")

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# 10b. Funcao que chama IA sem protecao de cota
# ---------------------------------------------------------------------------
#
# Cada chamada a um modelo de linguagem tem custo real por requisicao. Uma
# function que chama a API sem nenhum limite de uso e um vetor de custo sem
# teto: bug no cliente, loop, ou uso mal-intencionado rodam a fatura sem
# barreira nenhuma. clinicalAssist e parseLabText ja tiveram esse problema
# real, corrigido — esta checagem existe para pegar a proxima function que
# chamar IA e esquecer a cota.

for path in ts_sources():
    src = read(os.path.relpath(path, ROOT))
    name = os.path.basename(path)

    if "api.anthropic.com" not in src:
        continue

    has_quota = any(
        token in src
        for token in ("quota", "Quota", "rateLimit", "RateLimit", "_usage")
    )

    if not has_quota:
        finding(
            "ALTA",
            f"Chamada a IA sem protecao de custo: {name}",
            "Arquivo chama api.anthropic.com sem nenhuma referencia a cota "
            "ou limite de uso. Cada chamada tem custo real por requisicao.",
        )

# ---------------------------------------------------------------------------
# 10. Auditoria de acesso
# ---------------------------------------------------------------------------

audited_actions = [
    ("encounter_signed", "assinatura de prontuario"),
    ("document_issued", "emissao de documento"),
    ("professional_approved", "verificacao de registro profissional"),
    ("data_exported", "exportacao de dados"),
    ("deletion_requested", "pedido de exclusao"),
]

all_ts = "".join(open(p, encoding="utf-8").read() for p in ts_sources())

for action, label in audited_actions:
    if action not in all_ts:
        finding("MEDIA", f"Acao sem registro de auditoria: {label}", f'Esperado audit_log com action "{action}".')

if "match /audit_log/" in rules:
    block = re.search(r"match /audit_log/\{[^}]+\}\s*\{(.*?)\}", rules, re.DOTALL)
    if block and "if false" not in block.group(1):
        finding(
            "ALTA",
            "audit_log acessivel pelo cliente",
            "Registro de auditoria que o auditado pode alterar nao vale nada.",
        )

# ---------------------------------------------------------------------------
# Saida
# ---------------------------------------------------------------------------

ORDER = {"CRITICA": 0, "ALTA": 1, "MEDIA": 2, "BAIXA": 3}

if not findings:
    print("Auditoria de seguranca: nenhum achado.")
    print(f"  {len(declared)} collections com regra declarada")
    print(f"  {len(list(ts_sources()))} arquivos de Cloud Functions verificados")
    sys.exit(0)

findings.sort(key=lambda f: ORDER.get(f[0], 9))

print(f"{len(findings)} achado(s):\n")
for severity, title, detail in findings:
    print(f"[{severity}] {title}")
    print(f"         {detail}\n")

critical = sum(1 for f in findings if f[0] in ("CRITICA", "ALTA"))
sys.exit(1 if critical else 0)
