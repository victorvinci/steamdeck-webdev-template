import { test, expect, type Route } from '@playwright/test';

/**
 * Failure-path coverage for the /users route. The happy path lives in
 * `example.spec.ts` and hits the real backend; these tests stub `/api/users`
 * at the network layer via `page.route` so we can drive the UI into states
 * the real (seeded) backend can't easily produce: 503 errors, empty lists,
 * and retry-after-failure.
 */

const USERS_URL = '**/api/users*';

const fulfillError = (route: Route) =>
    route.fulfill({
        status: 503,
        contentType: 'application/json',
        body: JSON.stringify({ error: 'Database unavailable' }),
    });

const fulfillEmpty = (route: Route) =>
    route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ data: { users: [], total: 0 } }),
    });

const fulfillSeeded = (route: Route) =>
    route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
            data: {
                users: [
                    {
                        id: 1,
                        name: 'Ada Lovelace',
                        email: 'ada@example.com',
                        createdAt: '2026-04-12T00:00:00.000Z',
                    },
                ],
                total: 1,
            },
        }),
    });

test('shows an error alert with a Retry button when /api/users returns 503', async ({ page }) => {
    await page.route(USERS_URL, fulfillError);
    await page.goto('/users');

    const alert = page.getByRole('alert');
    await expect(alert).toBeVisible();
    await expect(alert).toContainText(/Could not load users/);
    await expect(page.getByRole('button', { name: 'Retry' })).toBeEnabled();
});

test('shows the empty-state status when the user list is empty', async ({ page }) => {
    await page.route(USERS_URL, fulfillEmpty);
    await page.goto('/users');

    const status = page.getByRole('status', { name: /No users yet/ });
    await expect(status).toBeVisible();
});

test('Retry refetches after a failed load and renders users on success', async ({ page }) => {
    let calls = 0;
    await page.route(USERS_URL, (route) => {
        calls += 1;
        return calls === 1 ? fulfillError(route) : fulfillSeeded(route);
    });

    await page.goto('/users');
    await expect(page.getByRole('alert')).toBeVisible();

    await page.getByRole('button', { name: 'Retry' }).click();

    const region = page.getByRole('region', { name: 'Users' });
    await expect(region).toBeVisible();
    await expect(region).toContainText('Ada Lovelace');
    expect(calls).toBeGreaterThanOrEqual(2);
});
