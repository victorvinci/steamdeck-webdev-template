import { defineConfig, devices } from '@playwright/test';
import { nxE2EPreset } from '@nx/playwright/preset';
import { workspaceRoot } from '@nx/devkit';

// For CI, you may want to set BASE_URL to the deployed application.
const baseURL = process.env['BASE_URL'] || 'http://localhost:4200';

/**
 * Read environment variables from file.
 * https://github.com/motdotla/dotenv
 */
// require('dotenv').config();

/**
 * See https://playwright.dev/docs/test-configuration.
 */
export default defineConfig({
    ...nxE2EPreset(__filename, { testDir: './src' }),
    /* Shared settings for all the projects below. See https://playwright.dev/docs/api/class-testoptions. */
    use: {
        baseURL,
        /* Collect trace when retrying the failed test. See https://playwright.dev/docs/trace-viewer */
        trace: 'on-first-retry',
    },
    /* Run both the frontend preview and the backend API before starting the tests.
     * The backend entry is load-bearing: backend-e2e's global-teardown kills port 3000
     * when it finishes, so if frontend-e2e ran after backend-e2e without starting its
     * own backend, every `/api/*` call from the browser would hit a dead port and the
     * UsersList region would never render. reuseExistingServer lets `npm run e2e:fe`
     * still work against a developer's already-running `npm run be`. */
    webServer: [
        {
            command: 'npx nx run frontend:preview',
            url: 'http://localhost:4200',
            reuseExistingServer: true,
            cwd: workspaceRoot,
        },
        {
            command: 'npx nx run backend:serve:development',
            // Use /ready so the backend isn't marked up until the DB pool is
            // actually reachable — prevents a race where tests hit /api/users
            // before mysql2 has opened its first connection.
            url: 'http://localhost:3000/api/health/ready',
            reuseExistingServer: true,
            cwd: workspaceRoot,
            timeout: 120_000,
        },
    ],
    projects: [
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'] },
        },

        {
            name: 'firefox',
            use: { ...devices['Desktop Firefox'] },
        },

        {
            name: 'webkit',
            use: { ...devices['Desktop Safari'] },
        },

        // Uncomment for mobile browsers support
        /* {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 12'] },
    }, */

        // Uncomment for branded browsers
        /* {
      name: 'Microsoft Edge',
      use: { ...devices['Desktop Edge'], channel: 'msedge' },
    },
    {
      name: 'Google Chrome',
      use: { ...devices['Desktop Chrome'], channel: 'chrome' },
    } */
    ],
});
