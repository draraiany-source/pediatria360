const { readFileSync } = require("node:fs");
const { resolve } = require("node:path");
const { test } = require("node:test");
const assert = require("node:assert/strict");

const rulesPath = resolve(__dirname, "../../../firestore.rules");
const rules = readFileSync(rulesPath, "utf8");

test("firestore.rules contains tenant ledger helpers", () => {
  assert.match(rules, /function canReadLedger\(\)/);
  assert.match(rules, /function canWriteFinanceLedger\(\)/);
  assert.match(rules, /function canWriteBillingLedger\(\)/);
  assert.match(rules, /function canWriteInventoryLedger\(\)/);
  assert.match(rules, /function ledgerClinicId\(\)/);
});

test("finance_receivables uses tenant helpers", () => {
  assert.match(rules, /match \/finance_receivables\/\{id\}/);
  assert.match(rules, /allow read: if canReadLedger\(\)/);
  assert.match(rules, /allow create, update: if canWriteFinanceLedger\(\)/);
});

test("emulator integration optional", async (t) => {
  if (process.env.FIRESTORE_EMULATOR_HOST == null) {
    t.skip("no emulator");
  }
});
