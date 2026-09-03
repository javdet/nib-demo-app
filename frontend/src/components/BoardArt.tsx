import { useId, useMemo } from 'react'

import type { Product } from '../lib/types'

/**
 * Product artwork, drawn rather than photographed.
 *
 * A store with no photographs is a store with no S3 bucket of assets to keep in
 * sync, and every board here is a rectangle in a frame anyway. Each product's
 * scribbles are derived from its slug, so a given product always looks the same
 * but no two look alike.
 */

const VIEW_W = 400
const VIEW_H = 300

function hash(text: string): number {
  let h = 2166136261
  for (let i = 0; i < text.length; i += 1) {
    h ^= text.charCodeAt(i)
    h = Math.imul(h, 16777619)
  }
  return h >>> 0
}

/** Small deterministic PRNG so artwork is stable across renders and reloads. */
function rng(seed: number): () => number {
  let a = seed
  return () => {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

interface Frame {
  x: number
  y: number
  w: number
  h: number
}

function fitBoard(product: Product): Frame {
  const ratio =
    product.width_mm && product.height_mm ? product.width_mm / product.height_mm : 4 / 3
  const maxW = VIEW_W - 56
  const maxH = VIEW_H - 64
  let w = maxW
  let h = w / ratio
  if (h > maxH) {
    h = maxH
    w = h * ratio
  }
  return { x: (VIEW_W - w) / 2, y: (VIEW_H - h) / 2 - 6, w, h }
}

/** A few chalk/marker strokes that look like the start of a diagram. */
function Scribbles({ frame, seed, stroke }: { frame: Frame; seed: number; stroke: string }) {
  const marks = useMemo(() => {
    const random = rng(seed)
    const pad = Math.min(frame.w, frame.h) * 0.16
    const x0 = frame.x + pad
    const y0 = frame.y + pad
    const w = frame.w - pad * 2
    const h = frame.h - pad * 2
    const nodes: { x: number; y: number; w: number; h: number }[] = []
    const count = 2 + Math.floor(random() * 2)
    for (let i = 0; i < count; i += 1) {
      const bw = w * (0.2 + random() * 0.12)
      const bh = h * (0.18 + random() * 0.1)
      nodes.push({
        x: x0 + random() * (w - bw),
        y: y0 + (h - bh) * (count === 1 ? 0.4 : i / Math.max(1, count - 1)) * 0.9,
        w: bw,
        h: bh,
      })
    }
    return nodes
  }, [frame, seed])

  return (
    <g stroke={stroke} fill="none" strokeLinecap="round" strokeLinejoin="round" opacity="0.85">
      {marks.map((m, i) => (
        <g key={i}>
          <rect x={m.x} y={m.y} width={m.w} height={m.h} rx={m.h * 0.22} strokeWidth={2} />
          <line
            x1={m.x + m.w * 0.16}
            y1={m.y + m.h * 0.62}
            x2={m.x + m.w * 0.7}
            y2={m.y + m.h * 0.62}
            strokeWidth={1.4}
            opacity={0.7}
          />
          {i > 0 && (
            <path
              d={`M ${marks[i - 1].x + marks[i - 1].w / 2} ${marks[i - 1].y + marks[i - 1].h}
                  C ${marks[i - 1].x + marks[i - 1].w / 2} ${m.y - 10},
                    ${m.x + m.w / 2} ${marks[i - 1].y + marks[i - 1].h + 10},
                    ${m.x + m.w / 2} ${m.y}`}
              strokeWidth={1.6}
              opacity={0.65}
            />
          )}
        </g>
      ))}
    </g>
  )
}

function AccessoryArt({ product, seed }: { product: Product; seed: number }) {
  const slug = product.slug
  const random = rng(seed)
  const palette = ['#d94f45', '#e0a83c', '#4f80c4', '#4f9d6b', '#8a5fc0', '#d8cfc0']

  if (slug.includes('marker') || slug.includes('chalk')) {
    const isChalk = slug.includes('chalk')
    const count = isChalk ? 6 : 5
    const stickW = isChalk ? 20 : 26
    const gap = 12
    const totalW = count * stickW + (count - 1) * gap
    return (
      <g>
        <rect
          x={(VIEW_W - totalW) / 2 - 22}
          y={96}
          width={totalW + 44}
          height={124}
          rx={10}
          fill="#e7e2d7"
          stroke="#c3bcae"
          strokeWidth={2}
        />
        {Array.from({ length: count }).map((_, i) => {
          const x = (VIEW_W - totalW) / 2 + i * (stickW + gap)
          const height = isChalk ? 78 + random() * 12 : 96
          return (
            <g key={i}>
              <rect
                x={x}
                y={190 - height}
                width={stickW}
                height={height}
                rx={isChalk ? 4 : 6}
                fill={palette[i % palette.length]}
              />
              {!isChalk && (
                <rect x={x} y={190 - height} width={stickW} height={16} rx={5} fill="#3c4147" />
              )}
            </g>
          )
        })}
      </g>
    )
  }

  if (slug.includes('eraser')) {
    return (
      <g>
        <rect x={110} y={120} width={180} height={64} rx={10} fill="#5b666e" />
        <rect x={110} y={168} width={180} height={40} rx={8} fill={product.accent} />
        <g stroke="#ffffff" strokeWidth={2} opacity={0.35}>
          {[0, 1, 2, 3].map((i) => (
            <line key={i} x1={126 + i * 44} y1={176} x2={126 + i * 44} y2={200} />
          ))}
        </g>
      </g>
    )
  }

  if (slug.includes('magnetic')) {
    return (
      <g>
        {[
          { x: 96, y: 104 },
          { x: 214, y: 104 },
          { x: 96, y: 186 },
          { x: 214, y: 186 },
        ].map((box, i) => (
          <rect
            key={i}
            x={box.x}
            y={box.y}
            width={90}
            height={48}
            rx={10}
            fill={palette[i % palette.length]}
            opacity={0.9}
          />
        ))}
        <g stroke={product.accent} strokeWidth={3} fill="none" strokeLinecap="round">
          <path d="M 186 128 L 214 128" />
          <path d="M 204 122 L 214 128 L 204 134" />
          <path d="M 141 152 L 141 186" />
          <path d="M 135 176 L 141 186 L 147 176" />
        </g>
      </g>
    )
  }

  return (
    <g>
      <rect x={132} y={92} width={56} height={116} rx={10} fill={product.accent} />
      <rect x={148} y={74} width={24} height={22} rx={5} fill="#4a5450" />
      <rect x={140} y={128} width={40} height={44} rx={4} fill="#f4f1ea" opacity={0.85} />
      <path
        d="M 208 138 q 34 -22 66 -4 q 26 16 8 44 q -20 30 -54 18 q -32 -12 -20 -58 z"
        fill="#e7e2d7"
        stroke="#c3bcae"
        strokeWidth={2}
      />
    </g>
  )
}

export function BoardArt({ product, className }: { product: Product; className?: string }) {
  const gradientId = useId()
  const seed = hash(product.slug)
  const frame = fitBoard(product)
  const inner = { x: frame.x + 10, y: frame.y + 10, w: frame.w - 20, h: frame.h - 20 }

  return (
    <svg
      className={className}
      viewBox={`0 0 ${VIEW_W} ${VIEW_H}`}
      role="img"
      aria-label={`Illustration of ${product.name}`}
      preserveAspectRatio="xMidYMid meet"
    >
      {product.surface === 'none' && <AccessoryArt product={product} seed={seed} />}

      {product.surface === 'chalk' && (
        <g>
          <rect
            x={frame.x}
            y={frame.y}
            width={frame.w}
            height={frame.h}
            rx={6}
            fill="#8a6a45"
            stroke="#6f5436"
            strokeWidth={2}
          />
          <rect
            x={inner.x}
            y={inner.y}
            width={inner.w}
            height={inner.h}
            rx={2}
            fill={product.accent}
          />
          <Scribbles frame={inner} seed={seed} stroke="rgba(255,255,255,0.8)" />
          <rect
            x={frame.x - 6}
            y={frame.y + frame.h}
            width={frame.w + 12}
            height={9}
            rx={3}
            fill="#7a5c3c"
          />
          <rect x={frame.x + 16} y={frame.y + frame.h + 1} width={26} height={5} rx={2} fill="#f2ede2" />
        </g>
      )}

      {product.surface === 'dry-erase' && (
        <g>
          <rect
            x={frame.x}
            y={frame.y}
            width={frame.w}
            height={frame.h}
            rx={6}
            fill="#c9ced2"
            stroke="#a8aeb3"
            strokeWidth={2}
          />
          <rect x={inner.x} y={inner.y} width={inner.w} height={inner.h} rx={2} fill="#fcfcfa" />
          <Scribbles frame={inner} seed={seed} stroke={product.accent} />
          <rect
            x={frame.x + frame.w * 0.28}
            y={frame.y + frame.h}
            width={frame.w * 0.44}
            height={8}
            rx={3}
            fill="#b4babf"
          />
        </g>
      )}

      {product.surface === 'glass' && (
        <g>
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#ffffff" stopOpacity="0.95" />
              <stop offset="55%" stopColor={product.accent} stopOpacity="0.28" />
              <stop offset="100%" stopColor="#ffffff" stopOpacity="0.9" />
            </linearGradient>
          </defs>
          <rect
            x={frame.x + 6}
            y={frame.y + 8}
            width={frame.w}
            height={frame.h}
            rx={4}
            fill="#0f1a18"
            opacity={0.12}
          />
          <rect
            x={frame.x}
            y={frame.y}
            width={frame.w}
            height={frame.h}
            rx={4}
            fill={`url(#${gradientId})`}
            stroke="#ffffff"
            strokeWidth={2}
          />
          <Scribbles frame={inner} seed={seed} stroke="#3f4a52" />
          {[
            [frame.x + 14, frame.y + 14],
            [frame.x + frame.w - 14, frame.y + 14],
            [frame.x + 14, frame.y + frame.h - 14],
            [frame.x + frame.w - 14, frame.y + frame.h - 14],
          ].map(([cx, cy], i) => (
            <circle key={i} cx={cx} cy={cy} r={4.5} fill="#8f979c" />
          ))}
        </g>
      )}

      {product.surface === 'cork' && (
        <g>
          <rect
            x={frame.x}
            y={frame.y}
            width={frame.w}
            height={frame.h}
            rx={6}
            fill="#8a6a45"
            stroke="#6f5436"
            strokeWidth={2}
          />
          <rect
            x={inner.x}
            y={inner.y}
            width={inner.w}
            height={inner.h}
            rx={2}
            fill={product.accent}
          />
          <g fill="#8c5f31" opacity={0.35}>
            {Array.from({ length: 60 }).map((_, i) => {
              const random = rng(seed + i)
              return (
                <circle
                  key={i}
                  cx={inner.x + random() * inner.w}
                  cy={inner.y + random() * inner.h}
                  r={0.8 + random() * 1.8}
                />
              )
            })}
          </g>
          {[0, 1, 2].map((i) => {
            const random = rng(seed * (i + 3))
            const cw = inner.w * 0.3
            const ch = inner.h * 0.26
            const x = inner.x + inner.w * 0.08 + random() * (inner.w * 0.84 - cw)
            const y = inner.y + inner.h * 0.1 + random() * (inner.h * 0.8 - ch)
            return (
              <g key={i} transform={`rotate(${(random() - 0.5) * 10} ${x + cw / 2} ${y + ch / 2})`}>
                <rect x={x} y={y} width={cw} height={ch} rx={2} fill="#f7f3e8" opacity={0.95} />
                <circle cx={x + cw / 2} cy={y + 7} r={4} fill={['#d94f45', '#4f80c4', '#4f9d6b'][i]} />
              </g>
            )
          })}
        </g>
      )}

      {product.surface === 'paper' && (
        <g>
          <rect
            x={frame.x}
            y={frame.y}
            width={frame.w}
            height={frame.h}
            rx={3}
            fill="#fdfbf5"
            stroke="#ddd6c4"
            strokeWidth={2}
          />
          <g stroke={product.accent} strokeWidth={0.7} opacity={0.55}>
            {Array.from({ length: Math.floor(frame.w / 18) }).map((_, i) => (
              <line
                key={`v${i}`}
                x1={frame.x + (i + 1) * 18}
                y1={frame.y}
                x2={frame.x + (i + 1) * 18}
                y2={frame.y + frame.h}
              />
            ))}
            {Array.from({ length: Math.floor(frame.h / 18) }).map((_, i) => (
              <line
                key={`h${i}`}
                x1={frame.x}
                y1={frame.y + (i + 1) * 18}
                x2={frame.x + frame.w}
                y2={frame.y + (i + 1) * 18}
              />
            ))}
          </g>
          <Scribbles frame={inner} seed={seed} stroke="#5d6b63" />
          <path
            d={`M ${frame.x + frame.w - 26} ${frame.y + frame.h}
                L ${frame.x + frame.w} ${frame.y + frame.h - 26}
                L ${frame.x + frame.w} ${frame.y + frame.h} Z`}
            fill="#ece5d3"
            stroke="#ddd6c4"
            strokeWidth={1.5}
          />
        </g>
      )}
    </svg>
  )
}
