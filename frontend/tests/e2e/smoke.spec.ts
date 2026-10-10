import { test, expect } from '@playwright/test'

// True end-to-end: real browser -> real nginx container -> real gunicorn
// backend. No mocks or stubs anywhere in these specs.

test('homepage loads with the backend greeting', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'How To Be Human' })).toBeVisible()
  await expect(page.getByText('Hello from Flask backend!')).toBeVisible()
})

test('backend health status is shown', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByText('healthy')).toBeVisible()
})

test('refresh button reloads the greeting', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByText('Hello from Flask backend!')).toBeVisible()

  await page.getByRole('button', { name: 'Refresh' }).click()

  await expect(page.getByText('Hello from Flask backend!')).toBeVisible()
})
