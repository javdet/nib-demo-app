import { Link } from 'react-router-dom'

import { api } from '../lib/api'
import { useAsync } from '../lib/useAsync'

/** Footer badge proving which container and database answered this page load. */
export function DeploymentStrip() {
  const { data, error } = useAsync(() => api.meta(), [])

  if (error) {
    return (
      <p className="deploy-strip deploy-strip--down">
        API unreachable - <Link to="/deployment">see what should be running</Link>
      </p>
    )
  }
  if (!data) return <p className="deploy-strip muted">Checking the backend...</p>

  return (
    <p className="deploy-strip">
      <span className={`dot ${data.database.reachable ? 'dot--up' : 'dot--down'}`} />
      <span>
        {data.environment} / {data.region}
      </span>
      <span className="sep">|</span>
      <span>api {data.version}</span>
      <span className="sep">|</span>
      <span>
        task <code>{(data.task_id ?? data.served_by).slice(0, 12)}</code>
      </span>
      <span className="sep">|</span>
      <Link to="/deployment">details</Link>
    </p>
  )
}
