import { test, expect } from '@playwright/test'

test('deep link serves the SPA fallback', async ({ page }) => {
  const resp = await page.goto('/dashboard/settings')
  expect(resp?.status()).toBe(200)
  await expect(page.getByRole('heading', { name: 'How To Be Human' })).toBeVisible()
})
