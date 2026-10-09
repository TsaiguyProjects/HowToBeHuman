import { useState, useEffect } from 'react'
import './App.css'

function App() {
  const [message, setMessage] = useState('')
  const [loading, setLoading] = useState(false)

  const fetchMessage = async () => {
    setLoading(true)
    try {
      const res = await fetch('/api/hello')
      const data = await res.json()
      setMessage(data.message || 'No message received')
    } catch (err) {
      setMessage('Error connecting to backend')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchMessage()
  }, [])

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
  const [status, setStatus] = useState('unknown')

  useEffect(() => {
    fetch('/api/health')
      .then(res => res.json())
      .then(data => setStatus(data.status || 'unknown'))
      .catch(() => setStatus('error'))
  }, [])

  const statusColors = {
    healthy: '#10b981',
    error: '#ef4444',
    unknown: '#f59e0b',
  }

  return (
    <div style={{ color: statusColors[status] }}>
      Status: <strong>{status}</strong>
    </div>
  )
}

export default App