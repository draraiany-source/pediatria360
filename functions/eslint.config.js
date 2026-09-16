// Configuração mínima, no formato "flat config" (ESLint 9+) — o mesmo que
// `npm run lint` chama. Não inventa regra customizada: usa o conjunto
// recomendado do @typescript-eslint, que é o padrão para projeto de
// Cloud Functions em TypeScript.
const tseslint = require("typescript-eslint");

module.exports = tseslint.config(
  {
    ignores: ["lib/**", "node_modules/**"],
  },
  ...tseslint.configs.recommended,
  {
    rules: {
      // O projeto usa `any` deliberadamente em alguns pontos ao ler dado
      // do Firestore (sem schema forte no SDK) — regra recomendada trata
      // isso como erro; aqui vira aviso, não bloqueia o lint por um
      // padrão que já é consciente, não descuido.
      "@typescript-eslint/no-explicit-any": "warn",
    },
  }
);
