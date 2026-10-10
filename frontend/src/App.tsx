import { useState, useEffect } from 'react'
import './App.scss'

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

function App() {
  const [message, setMessage] = useState<string>('')
  const [loading, setLoading] = useState<boolean>(true)

  useEffect(() => {
    let cancelled = false

    async function loadMessage(): Promise<void> {
      try {
        const res = await fetch('/api/hello')
        const data: HelloResponse = await res.json()
        if (!cancelled) {
          setMessage(data.message ?? 'No message received')
        }
      } catch {
        if (!cancelled) {
          setMessage('Error connecting to backend')
        }
      } finally {
        if (!cancelled) {
          setLoading(false)
        }
      }
    }

    void loadMessage()

    return () => {
      cancelled = true
    }
  }, [])

  const fetchMessage = async (): Promise<void> => {
    setLoading(true)
    try {
      const res = await fetch('/api/hello')
      const data: HelloResponse = await res.json()
      setMessage(data.message ?? 'No message received')
    } catch {
      setMessage('Error connecting to backend')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="app">
      <header>
        <h1>How To Be Human</h1>
      </header>
      <main>
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
    fetch('/api/health')
      .then((res) => res.json())
      .then((data: HealthResponse) => setStatus(data.status ?? 'unknown'))
      .catch(() => setStatus('error'))
  }, [])

  return (
    <div style={{ color: STATUS_COLORS[status] }}>
      Status: <strong>{status}</strong>
    </div>
  )
}

export default App
