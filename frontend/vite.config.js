import { defineConfig, searchForWorkspaceRoot } from 'vite';
import elmPlugin from 'vite-plugin-elm';
import path from 'node:path';

const frontendRoot = path.resolve(process.cwd());

export default defineConfig({
  root: frontendRoot,
  plugins: [
    // O atalho do pnpm em node_modules/.bin/elm executa o binário nativo via
    // `node` e quebra; apontar direto para o binário evita isso.
    elmPlugin({
      pathToElm: path.join(frontendRoot, 'node_modules/elm/bin/elm'),
    }),
  ],
  server: {
    fs: {
      allow: [
        searchForWorkspaceRoot(frontendRoot),
        frontendRoot,
        path.join(frontendRoot, 'src'),
      ],
    },
  },
});
