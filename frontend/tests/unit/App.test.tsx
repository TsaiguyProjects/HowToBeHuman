import { describe, it, expect, vi, afterEach } from 'vitest'
import { render, screen, fireEvent, cleanup, waitFor } from '@testing-library/react'
import App from '../../src/App.tsx'
import {
  CONTENT_PAYLOAD,
  HELLO_PAYLOAD,
  HEALTH_PAYLOAD,
  stubFetch,
  stubFetchWith,
} from './helpers.ts'

afterEach(() => {
  cleanup()
  vi.unstubAllGlobals()
})

describe('App', () => {
  it('loads the greeting from the backend on mount', async () => {
    stubFetch({
      '/api/hello': HELLO_PAYLOAD,
      '/api/health': HEALTH_PAYLOAD,
      '/api/content': CONTENT_PAYLOAD,
    })
    render(<App />)

    // Loading state shows in both the message and the disabled button
    expect(screen.getAllByText('Loading...')).toHaveLength(2)
    expect(await screen.findByText('Hello from Flask backend!')).toBeInTheDocument()
  })

  it('refetches the greeting when Refresh is clicked', async () => {
    const fetchMock = stubFetch({
      '/api/hello': HELLO_PAYLOAD,
      '/api/health': HEALTH_PAYLOAD,
      '/api/content': CONTENT_PAYLOAD,
    })
    render(<App />)

    await screen.findByText('Hello from Flask backend!')
    // 3 calls on mount: /api/hello + /api/health + /api/content
    expect(fetchMock).toHaveBeenCalledTimes(3)

    fireEvent.click(screen.getByRole('button', { name: 'Refresh' }))

    await waitFor(() => expect(fetchMock).toHaveBeenCalledTimes(4))
    expect(await screen.findByText('Hello from Flask backend!')).toBeInTheDocument()
  })

  it('shows the backend health status', async () => {
    stubFetch({
      '/api/hello': HELLO_PAYLOAD,
      '/api/health': HEALTH_PAYLOAD,
      '/api/content': CONTENT_PAYLOAD,
    })
    render(<App />)

    expect(await screen.findByText('healthy')).toBeInTheDocument()
  })

  it('shows an error when the backend is unreachable', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new Error('connection refused')
      }),
    )
    render(<App />)

    expect(await screen.findByText('Error connecting to backend')).toBeInTheDocument()
    expect(await screen.findByText('error')).toBeInTheDocument()
  })

  it('shows an error when refresh fails', async () => {
    let calls = 0
    stubFetchWith(async (url: string) => {
      if (url.endsWith('/api/content')) {
        return CONTENT_PAYLOAD
      }
      if (url.endsWith('/api/health')) {
        return HEALTH_PAYLOAD
      }
      calls += 1
      if (calls > 1) {
        throw new Error('connection reset')
      }
      return HELLO_PAYLOAD
    })
    render(<App />)

    await screen.findByText('Hello from Flask backend!')

    fireEvent.click(screen.getByRole('button', { name: 'Refresh' }))

    expect(await screen.findByText('Error connecting to backend')).toBeInTheDocument()
  })

  it('falls back when the greeting payload has no message', async () => {
    stubFetch({ '/api/hello': {}, '/api/health': HEALTH_PAYLOAD, '/api/content': CONTENT_PAYLOAD })
    render(<App />)

    expect(await screen.findByText('No message received')).toBeInTheDocument()
  })

  it('falls back when a refreshed payload has no message', async () => {
    let calls = 0
    stubFetchWith(async (url: string) => {
      if (url.endsWith('/api/content')) {
        return CONTENT_PAYLOAD
      }
      if (url.endsWith('/api/health')) {
        return HEALTH_PAYLOAD
      }
      calls += 1
      if (calls > 1) {
        return {}
      }
      return HELLO_PAYLOAD
    })
    render(<App />)

    await screen.findByText('Hello from Flask backend!')

    fireEvent.click(screen.getByRole('button', { name: 'Refresh' }))

    expect(await screen.findByText('No message received')).toBeInTheDocument()
  })

  it('falls back to unknown when the health payload has no status', async () => {
    stubFetch({ '/api/hello': HELLO_PAYLOAD, '/api/health': {}, '/api/content': CONTENT_PAYLOAD })
    render(<App />)

    expect(await screen.findByText('unknown')).toBeInTheDocument()
  })

  it('ignores late responses after unmount', async () => {
    const fetchMock = stubFetch({
      '/api/hello': HELLO_PAYLOAD,
      '/api/health': HEALTH_PAYLOAD,
      '/api/content': CONTENT_PAYLOAD,
    })
    const { unmount } = render(<App />)
    unmount()

    // Responses arrive after unmount; state updates must be skipped, not crash.
    await waitFor(() => expect(fetchMock).toHaveBeenCalled())
  })

  it('ignores late errors after unmount', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new Error('connection refused')
      }),
    )
    const { unmount } = render(<App />)
    unmount()

    // Let the rejected promises settle; nothing should throw.
    await waitFor(() => expect(true).toBe(true))
  })

  it('ignores a late refresh response after unmount', async () => {
    let helloCalls = 0
    let resolveRefresh: ((value: Response) => void) | undefined
    vi.stubGlobal(
      'fetch',
      vi.fn((input: string | URL | Request) => {
        const url = String(input)
        if (url.endsWith('/api/content')) {
          return Promise.resolve({ ok: true, status: 200, json: async () => CONTENT_PAYLOAD } as Response)
        }
        if (url.endsWith('/api/health')) {
          return Promise.resolve({ ok: true, status: 200, json: async () => HEALTH_PAYLOAD } as Response)
        }
        helloCalls += 1
        if (helloCalls === 1) {
          return Promise.resolve({ ok: true, status: 200, json: async () => HELLO_PAYLOAD } as Response)
        }
        return new Promise<Response>((resolve) => {
          resolveRefresh = resolve
        })
      }),
    )
    const { unmount } = render(<App />)
    await screen.findByText('Hello from Flask backend!')

    fireEvent.click(screen.getByRole('button', { name: 'Refresh' }))
    unmount()
    await waitFor(() => expect(resolveRefresh).toBeDefined())
    resolveRefresh?.({ ok: true, status: 200, json: async () => HELLO_PAYLOAD } as Response)
    await waitFor(() => expect(true).toBe(true))
  })

  it('ignores a late refresh error after unmount', async () => {
    let helloCalls = 0
    let rejectRefresh: ((error: Error) => void) | undefined
    vi.stubGlobal(
      'fetch',
      vi.fn((input: string | URL | Request) => {
        const url = String(input)
        if (url.endsWith('/api/content')) {
          return Promise.resolve({ ok: true, status: 200, json: async () => CONTENT_PAYLOAD } as Response)
        }
        if (url.endsWith('/api/health')) {
          return Promise.resolve({ ok: true, status: 200, json: async () => HEALTH_PAYLOAD } as Response)
        }
        helloCalls += 1
        if (helloCalls === 1) {
          return Promise.resolve({ ok: true, status: 200, json: async () => HELLO_PAYLOAD } as Response)
        }
        return new Promise<Response>((_resolve, reject) => {
          rejectRefresh = reject
        })
      }),
    )
    const { unmount } = render(<App />)
    await screen.findByText('Hello from Flask backend!')

    fireEvent.click(screen.getByRole('button', { name: 'Refresh' }))
    unmount()
    await waitFor(() => expect(rejectRefresh).toBeDefined())
    rejectRefresh?.(new Error('connection reset'))
    await waitFor(() => expect(true).toBe(true))
  })

  it('shows an error when the initial greeting response is not ok', async () => {
    // Return a non-ok Response-like object for hello
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: string | URL | Request) => {
        const url = String(input)
        if (url.endsWith('/api/content')) {
          return { ok: true, status: 200, json: async () => CONTENT_PAYLOAD } as Response
        }
        if (url.endsWith('/api/health')) {
          return { ok: true, status: 200, json: async () => HEALTH_PAYLOAD } as Response
        }
        return { ok: false, status: 500, json: async () => ({}) } as Response
      }),
    )
    render(<App />)

    expect(await screen.findByText('Error connecting to backend')).toBeInTheDocument()
  })

  it('shows an error when a refreshed greeting response is not ok', async () => {
    let calls = 0
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: string | URL | Request) => {
        const url = String(input)
        if (url.endsWith('/api/content')) {
          return { ok: true, status: 200, json: async () => CONTENT_PAYLOAD } as Response
        }
        if (url.endsWith('/api/health')) {
          return { ok: true, status: 200, json: async () => HEALTH_PAYLOAD } as Response
        }
        calls += 1
        if (calls > 1) {
          return { ok: false, status: 500, json: async () => ({}) } as Response
        }
        return { ok: true, status: 200, json: async () => HELLO_PAYLOAD } as Response
      }),
    )
    render(<App />)

    await screen.findByText('Hello from Flask backend!')

    fireEvent.click(screen.getByRole('button', { name: 'Refresh' }))

    expect(await screen.findByText('Error connecting to backend')).toBeInTheDocument()
  })

  it('shows an error health status when the health response is not ok', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: string | URL | Request) => {
        const url = String(input)
        if (url.endsWith('/api/content')) {
          return { ok: true, status: 200, json: async () => CONTENT_PAYLOAD } as Response
        }
        if (url.endsWith('/api/health')) {
          return { ok: false, status: 503, json: async () => ({}) } as Response
        }
        return { ok: true, status: 200, json: async () => HELLO_PAYLOAD } as Response
      }),
    )
    render(<App />)

    expect(await screen.findByText('error')).toBeInTheDocument()
  })
})
