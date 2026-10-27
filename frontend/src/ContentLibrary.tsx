import { useEffect, useState } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

import { selectDocumentPath } from './selectDocumentPath'

interface ContentIndex {
  version: string
  documents: string[]
}

function ContentLibrary() {
  const [contentIndex, setContentIndex] = useState<ContentIndex | null>(null)
  const [selectedPath, setSelectedPath] = useState<string | null>(null)
  const [markdown, setMarkdown] = useState<string | null>(null)
  const [indexLoading, setIndexLoading] = useState(true)
  const [documentLoading, setDocumentLoading] = useState(false)
  const [indexError, setIndexError] = useState(false)
  const [documentError, setDocumentError] = useState(false)

  useEffect(() => {
    let cancelled = false

    async function loadIndex(): Promise<void> {
      try {
        const response = await fetch('/api/content')
        if (!response.ok) {
          throw new Error('Content index request failed')
        }
        const payload: unknown = await response.json()
        if (
          typeof payload !== 'object' ||
          payload === null ||
          !('version' in payload) ||
          typeof payload.version !== 'string' ||
          !('documents' in payload) ||
          !Array.isArray(payload.documents) ||
          !payload.documents.every((document: unknown) => typeof document === 'string')
        ) {
          throw new Error('Content index response is invalid')
        }
        const contentPayload = payload as ContentIndex
        if (!cancelled) {
          setContentIndex(contentPayload)
          setSelectedPath((currentPath) => selectDocumentPath(currentPath, contentPayload.documents))
          setIndexError(false)
        }
      } catch {
        if (!cancelled) {
          setIndexError(true)
        }
      } finally {
        if (!cancelled) {
          setIndexLoading(false)
        }
      }
    }

    void loadIndex()
    const refresh = window.setInterval(() => void loadIndex(), 60_000)

    return () => {
      cancelled = true
      window.clearInterval(refresh)
    }
  }, [])

  useEffect(() => {
    if (contentIndex === null || selectedPath === null) {
      return
    }

    const activeIndex = contentIndex
    const activePath = selectedPath
    const controller = new AbortController()

    async function loadDocument(): Promise<void> {
      setDocumentLoading(true)
      setMarkdown(null)
      setDocumentError(false)

      const encodedPath = activePath
        .split('/')
        .map((segment) => encodeURIComponent(segment))
        .join('/')

      try {
        const response = await fetch(
          `/api/content/${encodeURIComponent(activeIndex.version)}/${encodedPath}`,
          { signal: controller.signal },
        )
        if (!response.ok) {
          throw new Error('Content document request failed')
        }
        setMarkdown(await response.text())
      } catch {
        if (!controller.signal.aborted) {
          setDocumentError(true)
        }
      } finally {
        if (!controller.signal.aborted) {
          setDocumentLoading(false)
        }
      }
    }

    void loadDocument()

    return () => controller.abort()
  }, [contentIndex, selectedPath])

  return (
    <section className="card content-library" aria-label="Content library">
      <h2>Library</h2>
      {indexLoading && <p role="status">Loading content library...</p>}
      {indexError && <p role="alert">Content library is unavailable.</p>}
      {contentIndex !== null && <p>Published version: {contentIndex.version}</p>}
      {contentIndex !== null && contentIndex.documents.length === 0 && (
        <p>No published documents yet.</p>
      )}
      {contentIndex !== null && contentIndex.documents.length > 0 && (
        <div className="content-layout">
          <nav className="content-list" aria-label="Documents">
            {contentIndex.documents.map((documentPath) => (
              <button
                aria-current={selectedPath === documentPath ? 'page' : undefined}
                key={documentPath}
                onClick={() => setSelectedPath(documentPath)}
                type="button"
              >
                {documentPath}
              </button>
            ))}
          </nav>
          <article className="markdown-content" aria-label="Selected document">
            {documentLoading && <p role="status">Loading document...</p>}
            {documentError && <p role="alert">Could not load this document.</p>}
            {markdown !== null && <ReactMarkdown remarkPlugins={[remarkGfm]}>{markdown}</ReactMarkdown>}
          </article>
        </div>
      )}
    </section>
  )
}

export default ContentLibrary