import { act, cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import ContentLibrary from '../../src/ContentLibrary'
import { jsonResponse, textResponse } from './helpers.ts'

interface ContentIndex {
  version: string
  documents: string[]
}

function setupContentApi(index: ContentIndex, documents: Record<string, string>) {
  const fetchMock = vi.fn(async (input: string | URL | Request) => {
    const url = String(input)
    if (url === '/api/content') {
      return jsonResponse(index)
    }
    const document = Object.entries(documents).find(([suffix]) => url.endsWith(suffix))
    if (document === undefined) {
      return textResponse('', false)
    }
    return textResponse(document[1])
  })
  vi.stubGlobal('fetch', fetchMock)
  return fetchMock
}

afterEach(() => {
  cleanup()
  vi.unstubAllGlobals()
  vi.useRealTimers()
})

describe('ContentLibrary', () => {
  it('loads and renders the first published markdown document', async () => {
    const version = '20261025T120000Z'
    const fetchMock = setupContentApi(
      { version, documents: ['index.mmd'] },
      { [`/api/content/${version}/index.mmd`]: '# Hello\n\nA **formatted** paragraph.' },
    )

    render(<ContentLibrary />)

    expect(await screen.findByRole('heading', { name: 'Hello' })).toBeInTheDocument()
    expect(screen.getByText('Published version: 20261025T120000Z')).toBeInTheDocument()
    expect(screen.getByText('formatted')).toHaveProperty('tagName', 'STRONG')
    expect(fetchMock).toHaveBeenCalledWith(
      '/api/content/20261025T120000Z/index.mmd',
      expect.objectContaining({ signal: expect.any(AbortSignal) }),
    )
  })

  it('renders a document list and loads a selected document', async () => {
    const version = '20261025T120000Z'
    setupContentApi(
      { version, documents: ['index.mmd', 'chapter two.mmd'] },
      {
        [`/api/content/${version}/index.mmd`]: '# Index',
        [`/api/content/${version}/chapter%20two.mmd`]: '# Chapter two',
      },
    )

    render(<ContentLibrary />)
    expect(await screen.findByRole('heading', { name: 'Index' })).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: 'chapter two.mmd' }))
    expect(await screen.findByRole('heading', { name: 'Chapter two' })).toBeInTheDocument()
  })

  it('shows the empty state when the newest directory has no markdown files', async () => {
    setupContentApi({ version: '20261025T120000Z', documents: [] }, {})

    render(<ContentLibrary />)

    expect(await screen.findByText('No published documents yet.')).toBeInTheDocument()
  })

  it('shows an unavailable message when the index endpoint returns an error', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => jsonResponse({}, false)))

    render(<ContentLibrary />)

    expect(await screen.findByRole('alert')).toHaveTextContent('Content library is unavailable.')
  })

  it('rejects a malformed content index response', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => jsonResponse({ version: 7, documents: null })))

    render(<ContentLibrary />)

    expect(await screen.findByRole('alert')).toHaveTextContent('Content library is unavailable.')
  })

  it('shows an unavailable message when loading the index throws', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => {
        throw new Error('network error')
      }),
    )

    render(<ContentLibrary />)

    expect(await screen.findByRole('alert')).toHaveTextContent('Content library is unavailable.')
  })

  it('shows an error when the selected document response is not successful', async () => {
    const version = '20261025T120000Z'
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: string | URL | Request) =>
        String(input) === '/api/content'
          ? jsonResponse({ version, documents: ['missing.mmd'] })
          : textResponse('', false),
      ),
    )

    render(<ContentLibrary />)

    expect(await screen.findByRole('alert')).toHaveTextContent('Could not load this document.')
  })

  it('shows an error when loading the selected document throws', async () => {
    const version = '20261025T120000Z'
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: string | URL | Request) => {
        if (String(input) === '/api/content') {
          return jsonResponse({ version, documents: ['chapter.mmd'] })
        }
        throw new Error('document network error')
      }),
    )

    render(<ContentLibrary />)

    expect(await screen.findByRole('alert')).toHaveTextContent('Could not load this document.')
  })

  it('updates to a newly published version during periodic refresh', async () => {
    vi.useFakeTimers()
    const versions: ContentIndex[] = [
      { version: '20261025T120000Z', documents: ['index.md'] },
      { version: '20261026T120000Z', documents: ['index.md'] },
    ]
    let indexRequest = 0
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: string | URL | Request) => {
        const url = String(input)
        if (url === '/api/content') {
          const index = versions[Math.min(indexRequest, versions.length - 1)]
          indexRequest += 1
          return jsonResponse(index)
        }
        return textResponse(`# ${url.includes('20261026') ? 'New' : 'Old'} version`)
      }),
    )

    render(<ContentLibrary />)
    await act(async () => {
      await Promise.resolve()
      await Promise.resolve()
      await Promise.resolve()
    })
    expect(screen.getByRole('heading', { name: 'Old version' })).toBeInTheDocument()

    await act(async () => {
      await vi.advanceTimersByTimeAsync(60_000)
    })
    expect(screen.getByRole('heading', { name: 'New version' })).toBeInTheDocument()
    expect(screen.getByText('Published version: 20261026T120000Z')).toBeInTheDocument()
  })

  it('selects the first document after refresh removes the selected path', async () => {
    vi.useFakeTimers()
    const versions: ContentIndex[] = [
      { version: '20261025T120000Z', documents: ['old.mmd'] },
      { version: '20261026T120000Z', documents: ['new.mmd'] },
    ]
    let indexRequest = 0
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: string | URL | Request) => {
        const url = String(input)
        if (url === '/api/content') {
          const index = versions[Math.min(indexRequest, versions.length - 1)]
          indexRequest += 1
          return jsonResponse(index)
        }
        return textResponse(`# ${url.includes('new.mmd') ? 'New' : 'Old'} document`)
      }),
    )

    render(<ContentLibrary />)
    await act(async () => {
      await Promise.resolve()
      await Promise.resolve()
      await Promise.resolve()
    })
    expect(screen.getByRole('heading', { name: 'Old document' })).toBeInTheDocument()

    await act(async () => {
      await vi.advanceTimersByTimeAsync(60_000)
    })

    expect(screen.getByRole('button', { name: 'new.mmd' })).toHaveAttribute('aria-current', 'page')
    expect(screen.getByRole('heading', { name: 'New document' })).toBeInTheDocument()
  })

  it('ignores an index response that arrives after unmount', async () => {
    let resolveIndex: ((response: Response) => void) | undefined
    vi.stubGlobal(
      'fetch',
      vi.fn(
        () =>
          new Promise<Response>((resolve) => {
            resolveIndex = resolve
          }),
      ),
    )

    const { unmount } = render(<ContentLibrary />)
    unmount()
    await act(async () => {
      resolveIndex?.(jsonResponse({ version: '20261025T120000Z', documents: [] }))
      await Promise.resolve()
    })
  })

  it('ignores an index error that arrives after unmount', async () => {
    let rejectIndex: ((error: Error) => void) | undefined
    vi.stubGlobal(
      'fetch',
      vi.fn(
        () =>
          new Promise<Response>((_resolve, reject) => {
            rejectIndex = reject
          }),
      ),
    )

    const { unmount } = render(<ContentLibrary />)
    unmount()
    await act(async () => {
      rejectIndex?.(new Error('late index failure'))
      await Promise.resolve()
    })
  })

  it('aborts an in-flight document request when unmounted', async () => {
    const version = '20261025T120000Z'
    let documentStarted = false
    const pendingDocument = (signal: AbortSignal): Promise<Response> =>
      new Promise((_resolve, reject) => {
        documentStarted = true
        signal.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')))
        if (signal.aborted) {
          reject(new DOMException('Aborted', 'AbortError'))
        }
      })
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
        if (String(input) === '/api/content') {
          return jsonResponse({ version, documents: ['chapter.mmd'] })
        }
        return pendingDocument(init?.signal as AbortSignal)
      }),
    )

    const { unmount } = render(<ContentLibrary />)
    await screen.findByText('Loading document...')
    expect(documentStarted).toBe(true)
    unmount()
    await act(async () => Promise.resolve())
  })
})
