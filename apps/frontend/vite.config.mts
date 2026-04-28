/// <reference types='vitest' />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { nxViteTsPaths } from '@nx/vite/plugins/nx-tsconfig-paths.plugin';
import { nxCopyAssetsPlugin } from '@nx/vite/plugins/nx-copy-assets.plugin';
import { TanStackRouterVite } from '@tanstack/router-plugin/vite';

export default defineConfig(() => ({
    root: import.meta.dirname,
    cacheDir: '../../node_modules/.vite/apps/frontend',
    server: {
        port: 4200,
        host: 'localhost',
    },
    preview: {
        port: 4200,
        host: 'localhost',
    },
    plugins: [
        TanStackRouterVite({ target: 'react', routesDirectory: './src/routes' }),
        react(),
        nxViteTsPaths(),
        nxCopyAssetsPlugin(['*.md']),
    ],
    // Uncomment this if you are using workers.
    // worker: {
    //   plugins: () => [ nxViteTsPaths() ],
    // },
    build: {
        outDir: '../../dist/apps/frontend',
        emptyOutDir: true,
        reportCompressedSize: true,
        commonjsOptions: {
            transformMixedEsModules: true,
        },
    },
    test: {
        name: 'frontend',
        watch: false,
        globals: true,
        environment: 'jsdom',
        include: ['{src,tests}/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'],
        reporters: ['default'],
        coverage: {
            reportsDirectory: '../../coverage/apps/frontend',
            provider: 'v8' as const,
            // Without `include`, vitest only reports coverage for files
            // actually loaded by tests — which makes "100% coverage" a
            // trivial pass even when most files have no tests. Listing
            // src/** explicitly makes uncovered files show as 0% so the
            // thresholds below can fail on real regressions.
            //
            // Excludes:
            //   - main.tsx           Vite entry, exercised via e2e
            //   - routeTree.gen.ts   TanStack Router generated file
            //   - routes/**          thin route components, exercised via e2e
            //   - *.{test,spec,stories}.{ts,tsx}   tests + storybook stories
            include: ['src/**/*.{ts,tsx}'],
            exclude: [
                'src/main.tsx',
                'src/routeTree.gen.ts',
                'src/routes/**',
                'src/**/*.{test,spec,stories}.{ts,tsx}',
            ],
            // Calibrated 2026-04-27 against:
            //   statements 29.62  branches 33.33  lines 30.76  functions 40
            // The frontend is intentionally thin on unit tests right now —
            // the worked /users domain is the only component with a spec,
            // and most of the surface area is exercised via Playwright e2e
            // (apps/frontend-e2e) instead. Floors are deliberately low to
            // act as a regression net, not a goalpost; bump in dedicated
            // PRs once new specs land. See apps/backend/jest.config.cts
            // for the same rationale.
            thresholds: {
                statements: 25,
                branches: 30,
                lines: 25,
                functions: 35,
            },
        },
    },
}));
