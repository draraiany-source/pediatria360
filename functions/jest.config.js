/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  roots: ["<rootDir>/src"],
  testMatch: ["**/*.test.ts"],
  // Testes de unidade só — nada que precise de Firestore/emulador. Regras
  // de segurança já têm suíte própria em test/rules/, com o emulador de
  // verdade. Misturar os dois aqui tornaria esta suíte lenta e frágil por
  // um motivo que não é dela: infraestrutura de rede, não lógica.
  testPathIgnorePatterns: ["/node_modules/", "/lib/"],
};
