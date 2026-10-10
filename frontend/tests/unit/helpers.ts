import { vi } from 'vitest'

export const HELLO_PAYLOAD = { message: 'Hello from Flask backend!' }
export const HEALTH_PAYLOAD = { status: 'healthy', service: 'flask-backend' }

/** Stub the fetch boundary with canned routes (no backend needed for unit tests). */
export function stubFetch(routes: Record<string, unknown>) {
  const fetchMock = vi.fn(async (input: string | URL | Request) => {
    const url = String(input)
    const match = Object.keys(routes).find((route) => url.endsWith(route))
    if (match === undefined) {
      throw new Error(`unexpected fetch: ${url}`)
    }
    return {
      ok: true,
      status: 200,
      json: async (): Promise<unknown> => routes[match],
    }
  })
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

/** Stub fetch with per-URL handlers for failure-path tests. */
export function stubFetchWith(
  handler: (url: string) => Promise<unknown>,
) {
  const fetchMock = vi.fn(async (input: string | URL | Request) => ({
    ok: true,
    status: 200,
    json: (): Promise<unknown> => handler(String(input)),
  }))
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}
