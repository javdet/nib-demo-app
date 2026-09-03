import { ArchitectureDiagram } from '../components/ArchitectureDiagram'
import { ErrorState, Loading } from '../components/States'
import { api } from '../lib/api'
import { formatDate, formatUptime } from '../lib/format'
import { useAsync } from '../lib/useAsync'

const PIECES = [
  {
    name: 'React SPA',
    detail:
      'Built with Vite into a hashed bundle and synced to a private S3 bucket. index.html is uploaded last, with a short cache lifetime, so a deploy never serves a new shell against old assets.',
  },
  {
    name: 'CloudFront',
    detail:
      'The only public entrance. It reads S3 through an Origin Access Control (the bucket itself stays private), terminates TLS, and rewrites unknown paths to /index.html so client-side routes survive a hard refresh.',
  },
  {
    name: 'Application Load Balancer',
    detail:
      'A second CloudFront origin, matched on /api/*. It health-checks /api/health/ready, so a task that cannot reach the database is pulled out of rotation instead of returning errors.',
  },
  {
    name: 'ECS Fargate',
    detail:
      'The FastAPI image from ECR, running as a non-root user with no EC2 hosts to patch. Each task applies Alembic migrations at startup and then serves; scaling out is a desired-count change.',
  },
  {
    name: 'RDS for PostgreSQL',
    detail:
      'In private subnets, reachable only from the task security group. It holds the catalogue, every cart and every order - which is why the cart survives a page reload and a task replacement.',
  },
]

const REQUEST_PATH = [
  'The browser resolves the CloudFront domain and fetches index.html from the edge cache.',
  'The SPA boots, reads /config.json for its API origin, and calls /api/products.',
  'CloudFront matches /api/* to the load balancer origin and forwards the request, uncached.',
  'The ALB picks a healthy Fargate task and proxies to port 8000.',
  'FastAPI queries RDS over the private subnet and returns JSON, which renders as the grid.',
]

export function DeploymentPage() {
  const { data: meta, error, loading, reload } = useAsync(() => api.meta(), [])

  return (
    <section className="shell section">
      <h1>How this is deployed</h1>
      <p className="lede">
        The store is the demonstration, not the point. Below is the path a request actually takes,
        and a panel showing which container and which database answered the one you just made.
      </p>

      <ArchitectureDiagram />

      <div className="two-col">
        <div>
          <h2>What each piece does</h2>
          <dl className="pieces">
            {PIECES.map((piece) => (
              <div key={piece.name}>
                <dt>{piece.name}</dt>
                <dd>{piece.detail}</dd>
              </div>
            ))}
          </dl>
        </div>

        <div>
          <h2>One request, end to end</h2>
          <ol className="steps">
            {REQUEST_PATH.map((step) => (
              <li key={step}>{step}</li>
            ))}
          </ol>

          <h2>Live backend</h2>
          {loading && <Loading label="Asking the API who it is..." />}
          {error && <ErrorState message={error} onRetry={reload} />}
          {meta && (
            <>
              <table className="facts">
                <tbody>
                  <tr>
                    <th scope="row">Environment</th>
                    <td>
                      {meta.environment} / {meta.region}
                    </td>
                  </tr>
                  <tr>
                    <th scope="row">API version</th>
                    <td>
                      {meta.version} (<code>{meta.git_sha}</code>)
                    </td>
                  </tr>
                  <tr>
                    <th scope="row">Served by</th>
                    <td>
                      <code>{meta.task_id ?? meta.served_by}</code>
                    </td>
                  </tr>
                  <tr>
                    <th scope="row">Task uptime</th>
                    <td>{formatUptime(meta.uptime_seconds)}</td>
                  </tr>
                  <tr>
                    <th scope="row">Database</th>
                    <td>
                      {meta.database.dialect} - {meta.database.name} @ {meta.database.host}
                    </td>
                  </tr>
                  <tr>
                    <th scope="row">Database round trip</th>
                    <td>
                      {meta.database.reachable ? (
                        <>
                          <span className="dot dot--up" /> {meta.database.latency_ms} ms
                        </>
                      ) : (
                        <>
                          <span className="dot dot--down" /> unreachable
                          {meta.database.error ? ` (${meta.database.error})` : ''}
                        </>
                      )}
                    </td>
                  </tr>
                  <tr>
                    <th scope="row">Answered at</th>
                    <td>{formatDate(meta.served_at)}</td>
                  </tr>
                </tbody>
              </table>
              <button type="button" className="btn btn--ghost" onClick={reload}>
                Ask again
              </button>
              <p className="muted small">
                With more than one task behind the load balancer, the &ldquo;served by&rdquo; value
                changes as you repeat the call. Locally it is just the container hostname.
              </p>
            </>
          )}
        </div>
      </div>
    </section>
  )
}
