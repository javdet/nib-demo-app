/** The request path, drawn once so the words on this page have something to point at. */

interface BoxProps {
  x: number
  y: number
  w: number
  h: number
  title: string
  subtitle?: string
  tone?: 'edge' | 'compute' | 'data' | 'client'
}

const TONES: Record<string, { fill: string; stroke: string }> = {
  client: { fill: 'var(--diagram-client)', stroke: 'var(--diagram-client-line)' },
  edge: { fill: 'var(--diagram-edge)', stroke: 'var(--diagram-edge-line)' },
  compute: { fill: 'var(--diagram-compute)', stroke: 'var(--diagram-compute-line)' },
  data: { fill: 'var(--diagram-data)', stroke: 'var(--diagram-data-line)' },
}

function Box({ x, y, w, h, title, subtitle, tone = 'compute' }: BoxProps) {
  const { fill, stroke } = TONES[tone]
  return (
    <g>
      <rect x={x} y={y} width={w} height={h} rx={10} fill={fill} stroke={stroke} strokeWidth={1.5} />
      <text x={x + w / 2} y={y + (subtitle ? h / 2 - 4 : h / 2 + 5)} className="dg-title">
        {title}
      </text>
      {subtitle && (
        <text x={x + w / 2} y={y + h / 2 + 15} className="dg-sub">
          {subtitle}
        </text>
      )}
    </g>
  )
}

function Arrow({ x1, y1, x2, y2, label }: { x1: number; y1: number; x2: number; y2: number; label?: string }) {
  return (
    <g>
      <line x1={x1} y1={y1} x2={x2 - 8} y2={y2} className="dg-line" markerEnd="url(#dg-arrow)" />
      {label && (
        <text x={(x1 + x2) / 2} y={y1 - 9} className="dg-label">
          {label}
        </text>
      )}
    </g>
  )
}

export function ArchitectureDiagram() {
  return (
    <div className="diagram-scroll">
      <svg
        viewBox="0 0 940 330"
        className="diagram"
        role="img"
        aria-label="Browser to CloudFront to Application Load Balancer to ECS Fargate tasks to RDS Postgres"
      >
        <defs>
          <marker id="dg-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
            <path d="M 0 0 L 10 5 L 0 10 z" className="dg-arrowhead" />
          </marker>
        </defs>

        <text x={20} y={26} className="dg-region">Browser</text>
        <text x={190} y={26} className="dg-region">Edge</text>
        <text x={430} y={26} className="dg-region">VPC - public subnets</text>
        <text x={648} y={26} className="dg-region">VPC - private subnets</text>

        <rect x={178} y={38} width={196} height={230} rx={12} className="dg-zone" />
        <rect x={396} y={38} width={190} height={230} rx={12} className="dg-zone" />
        <rect x={608} y={38} width={312} height={230} rx={12} className="dg-zone" />

        <Box x={20} y={120} w={130} h={64} title="React SPA" subtitle="Vite bundle" tone="client" />

        <Box x={196} y={72} w={160} h={64} title="CloudFront" subtitle="TLS, cache, SPA fallback" tone="edge" />
        <Box x={196} y={182} w={160} h={64} title="S3 bucket" subtitle="private, OAC only" tone="edge" />

        <Box x={412} y={120} w={158} h={64} title="ALB" subtitle="HTTPS :443" tone="compute" />

        <Box x={628} y={84} w={150} h={54} title="Fargate task" subtitle="FastAPI, :8000" tone="compute" />
        <Box x={628} y={152} w={150} h={54} title="Fargate task" subtitle="FastAPI, :8000" tone="compute" />

        <Box x={806} y={118} w={104} h={70} title="RDS" subtitle="Postgres 16" tone="data" />

        <Arrow x1={150} y1={152} x2={196} y2={152} />
        <Arrow x1={276} y1={136} x2={276} y2={182} />
        <Arrow x1={356} y1={124} x2={412} y2={140} label="/api/*" />
        <Arrow x1={570} y1={140} x2={628} y2={111} />
        <Arrow x1={570} y1={164} x2={628} y2={179} />
        <Arrow x1={778} y1={111} x2={806} y2={140} />
        <Arrow x1={778} y1={179} x2={806} y2={166} />

        <text x={20} y={294} className="dg-note">
          <tspan x={20} dy={0}>
            Static assets are cached at the edge; /api/* is forwarded to the load balancer.
          </tspan>
          <tspan x={20} dy={16}>
            The SPA and the API therefore share one origin - the browser never makes a
            cross-origin request.
          </tspan>
        </text>
      </svg>
    </div>
  )
}
