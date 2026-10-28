import { useState, useEffect, useRef } from 'react'
import './App.scss'
import ContentLibrary from './ContentLibrary'

interface HelloResponse {
  message?: string
}

type HealthStatus = 'healthy' | 'error' | 'unknown'

interface HealthResponse {
  status?: HealthStatus
}

const STATUS_COLORS: Record<HealthStatus, string> = {
  healthy: '#10b981',
  error: '#ef4444',
  unknown: '#f59e0b',
}

async function fetchHello(): Promise<string> {
  const res = await fetch('/api/hello')
  if (!res.ok) throw new Error(`HTTP ${res.status}`)
  const data: HelloResponse = await res.json()
  return data.message ?? 'No message received'
}

function App() {
  const [message, setMessage] = useState<string>('')
  const [loading, setLoading] = useState<boolean>(true)
  const mountedRef = useRef(true)

  useEffect(() => {
    mountedRef.current = true
    let cancelled = false

    async function loadMessage(): Promise<void> {
      try {
        const msg = await fetchHello()
        if (!cancelled && mountedRef.current) setMessage(msg)
      } catch {
        if (!cancelled && mountedRef.current) setMessage('Error connecting to backend')
      } finally {
        if (!cancelled && mountedRef.current) setLoading(false)
      }
    }

    void loadMessage()

    return () => {
      cancelled = true
      mountedRef.current = false
    }
  }, [])

  const fetchMessage = async (): Promise<void> => {
    if (!mountedRef.current) return
    setLoading(true)
    try {
      const msg = await fetchHello()
      if (mountedRef.current) setMessage(msg)
    } catch {
      if (mountedRef.current) setMessage('Error connecting to backend')
    } finally {
      if (mountedRef.current) setLoading(false)
    }
  }

  return (
    <div className="app">
      <header>
        <h1>How To Be Human</h1>
      </header>
      <main>
        <ContentLibrary />
        <section className="card">
          <h2>Backend Connection Test</h2>
          <p>{loading ? 'Loading...' : message}</p>
          <button onClick={fetchMessage} disabled={loading}>
            {loading ? 'Loading...' : 'Refresh'}
          </button>
        </section>

        <section className="card">
          <h2>Health Check</h2>
          <HealthCheck />
        </section>
      </main>
    </div>
  )
}

function HealthCheck() {
  const [status, setStatus] = useState<HealthStatus>('unknown')

  useEffect(() => {
    let cancelled = false

    async function loadStatus(): Promise<void> {
      try {
        const res = await fetch('/api/health')
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        const data: HealthResponse = await res.json()
        if (!cancelled) setStatus(data.status ?? 'unknown')
      } catch {
        if (!cancelled) setStatus('error')
      }
    }

    void loadStatus()

    return () => {
      cancelled = true
    }
  }, [])

  return (
    <div style={{ color: STATUS_COLORS[status] }}>
      Status: <strong>{status}</strong>
    </div>
  )
}

export default App
