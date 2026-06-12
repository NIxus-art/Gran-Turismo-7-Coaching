import { useState, useEffect } from 'react'

type Telemetry = { speed: number; rpm: number; brake: number; throttle: number; gear: number }
type Corner = { id: number; name: string; brake: number; apex: number; throttle: number }
type Tune = { suspension: number[]; gearRatios: number[] }
type Track = { id: string; name: string; description: string; corners: Corner[]; tune: Tune }
type Plan = { price: number; currency: string; name: string }
type Subscription = { monthly: Plan; yearly: Plan; bankAccount: string }

const trimTrailingSlash = (value: string) => value.replace(/\/+$/, '')

const getApiBaseUrl = () => {
  const configured = import.meta.env.VITE_API_BASE_URL
  if (configured) return trimTrailingSlash(configured)

  if (typeof window !== 'undefined' && window.location.hostname !== 'localhost') {
    return trimTrailingSlash(window.location.origin)
  }

  return 'http://localhost:3001'
}

const getWsUrl = (apiBaseUrl: string) => {
  const configured = import.meta.env.VITE_WS_URL
  if (configured) return configured

  return `${apiBaseUrl.replace(/^http/, 'ws')}/ws`
}

function App() {
  const [activeTab, setActiveTab] = useState<'telemetry' | 'tracks' | 'subscription'>('telemetry')
  const [telemetry, setTelemetry] = useState<Telemetry | null>(null)
  const [tracks, setTracks] = useState<Track[]>([])
  const [subscription, setSubscription] = useState<Subscription | null>(null)
  const [loadingTracks, setLoadingTracks] = useState(true)
  const [loadingSubscription, setLoadingSubscription] = useState(true)
  const [wsConnected, setWsConnected] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const apiBaseUrl = getApiBaseUrl()
  const wsUrl = getWsUrl(apiBaseUrl)

  useEffect(() => {
    // WebSocket connection to backend
    const ws = new WebSocket(wsUrl)
    
    ws.onopen = () => {
      setWsConnected(true)
      setError(null)
    }
    
    ws.onmessage = (event) => {
      try {
        setTelemetry(JSON.parse(event.data) as Telemetry)
      } catch (e) {
        console.error('Failed to parse telemetry:', e)
      }
    }
    
    ws.onclose = () => {
      setWsConnected(false)
      setError('Disconnected from server. Reconnecting...')
    }
    
    ws.onerror = () => {
      setError('WebSocket connection error')
    }

    // Fetch tracks
    fetch(`${apiBaseUrl}/tracks`)
      .then(res => res.json())
      .then((data: Track[]) => {
        setTracks(data)
        setLoadingTracks(false)
      })
      .catch(err => {
        console.error('Failed to fetch tracks:', err)
        setError('Failed to load tracks')
        setLoadingTracks(false)
      })
    
    // Fetch subscription info
    fetch(`${apiBaseUrl}/subscription`)
      .then(res => res.json())
      .then((data: Subscription) => {
        setSubscription(data)
        setLoadingSubscription(false)
      })
      .catch(err => {
        console.error('Failed to fetch subscription:', err)
        setError('Failed to load subscription info')
        setLoadingSubscription(false)
      })

    return () => ws.close()
  }, [apiBaseUrl, wsUrl])

  return (
    <div className="container">
      <header>
        <div className="logo">GT7</div>
        <h1>Driving Coach</h1>
        <nav>
          <button onClick={() => setActiveTab('telemetry')}>Telemetry</button>
          <button onClick={() => setActiveTab('tracks')}>Tracks</button>
          <button onClick={() => setActiveTab('subscription')}>Subscribe</button>
        </nav>
      </header>

      {error && (
        <div style={{ background: 'rgba(233, 69, 96, 0.2)', padding: '15px', borderRadius: '10px', marginBottom: '20px', border: '1px solid #e94560' }}>
          ⚠️ {error}
        </div>
      )}

      {activeTab === 'telemetry' && (
        <div>
          {!wsConnected && <p>Connecting to telemetry...</p>}
          {telemetry && (
            <div className="telemetry">
              <div className="telemetry-card">
                <div className="telemetry-value">{telemetry.speed.toFixed(0)} km/h</div>
                <div>Speed</div>
              </div>
              <div className="telemetry-card">
                <div className="telemetry-value">{telemetry.rpm.toFixed(0)} RPM</div>
                <div>Engine</div>
              </div>
              <div className="telemetry-card">
                <div className="telemetry-value">{telemetry.brake.toFixed(0)}%</div>
                <div>Brake</div>
              </div>
              <div className="telemetry-card">
                <div className="telemetry-value">{telemetry.throttle.toFixed(0)}%</div>
                <div>Throttle</div>
              </div>
              <div className="telemetry-card">
                <div className="telemetry-value">{telemetry.gear}</div>
                <div>Gear</div>
              </div>
            </div>
          )}
        </div>
      )}

      {activeTab === 'tracks' && (
        <div>
          {loadingTracks && <p>Loading tracks...</p>}
          {!loadingTracks && (
            <div className="track-list">
              {tracks.map((track: Track) => (
                <div key={track.id} className="track-card">
                  <h3>{track.name}</h3>
                  <p>{track.description}</p>
                  <h4 style={{ marginTop: '15px' }}>Corners:</h4>
                  {track.corners.map((corner: Corner, i: number) => (
                    <div key={i} style={{ padding: '10px 0' }}>
                      <strong>{corner.name}</strong> Brake {corner.brake}% → Apex {corner.apex}% → Throttle {corner.throttle}%
                    </div>
                  ))}
                  <h4 style={{ marginTop: '15px' }}>Perfect Tune:</h4>
                  <div>Suspension: {track.tune.suspension.join(', ')}</div>
                  <div>Gear Ratios: {track.tune.gearRatios.join(', ')}</div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {activeTab === 'subscription' && (
        <div>
          {loadingSubscription && <p>Loading subscription plans...</p>}
          {!loadingSubscription && subscription && (
            <>
              <div className="subscription">
                <div className="subscription-card">
                  <h3>{subscription.monthly.name}</h3>
                  <div className="price">€{subscription.monthly.price}</div>
                  <p>per month</p>
                  <button className="subscribe-btn">Subscribe</button>
                </div>
                <div className="subscription-card">
                  <h3>{subscription.yearly.name}</h3>
                  <div className="price">€{subscription.yearly.price}</div>
                  <p>per year (save 17%)</p>
                  <button className="subscribe-btn">Subscribe</button>
                </div>
              </div>
              <div style={{ marginTop: '40px', padding: '20px', background: 'rgba(255,255,255,0.05)', borderRadius: '15px' }}>
                <h3>Payment Details</h3>
                <p>Bank Account: {subscription.bankAccount}</p>
                <p>Please transfer the subscription amount to this bank account.</p>
              </div>
            </>
          )}
        </div>
      )}
    </div>
  )
}

export default App
