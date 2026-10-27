import { describe, it, expect, vi, afterEach } from 'vitest'
import { screen, cleanup } from '@testing-library/react'
import { HELLO_PAYLOAD, HEALTH_PAYLOAD, stubFetch } from './helpers.ts'

afterEach(() => {
  cleanup()
  vi.unstubAllGlobals()
})

describe('main entry', () => {
  it('renders the app into #root', async () => {
    document.body.innerHTML = '<div id="root"></div>'
    stubFetch({ '/api/hello': HELLO_PAYLOAD, '/api/health': HEALTH_PAYLOAD })

    await import('../../src/main.tsx')

    expect(
      await screen.findByRole('heading', { name: 'How To Be Human' }),
    ).toBeInTheDocument()
    expect(await screen.findByText('Hello from Flask backend!')).toBeInTheDocument()
  })
})
