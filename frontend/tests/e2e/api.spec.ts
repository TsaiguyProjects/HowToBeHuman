import { test, expect } from '@playwright/test'

// API-level assertions over real HTTP through the nginx reverse proxy.

test('health endpoint returns service status', async ({ request }) => {
  const resp = await request.get('/api/health')
  expect(resp.ok()).toBeTruthy()
  expect(await resp.json()).toEqual({ status: 'healthy', service: 'flask-backend' })
})

test('hello endpoint returns the greeting', async ({ request }) => {
  const resp = await request.get('/api/hello')
  expect(resp.ok()).toBeTruthy()
  expect(await resp.json()).toEqual({ message: 'Hello from Flask backend!' })
})

test('unknown API route returns a JSON 404, not the SPA', async ({ request }) => {
  const resp = await request.get('/api/does-not-exist')
  expect(resp.status()).toBe(404)
  expect(await resp.json()).toEqual({ error: 'Not found' })
})
