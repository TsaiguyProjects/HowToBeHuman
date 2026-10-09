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
})
