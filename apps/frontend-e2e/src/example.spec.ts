import { test, expect } from '@playwright/test';

test('home page renders the boilerplate heading', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('h1')).toHaveText('Steamdeck Webdev Template');
});

test('home page eventually shows the users list from the backend', async ({ page }) => {
    await page.goto('/');
    // The list depends on the backend being up with the seed data loaded.
    await expect(page.getByRole('region', { name: 'Users' })).toBeVisible({ timeout: 10_000 });
});
