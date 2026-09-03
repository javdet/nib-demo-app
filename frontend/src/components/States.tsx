import type { ReactNode } from 'react'

export function Loading({ label = 'Loading...' }: { label?: string }) {
  return (
    <p className="state" role="status">
      {label}
    </p>
  )
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="state state--error" role="alert">
      <p>{message}</p>
      {onRetry && (
        <button type="button" className="btn btn--ghost" onClick={onRetry}>
          Try again
        </button>
      )}
    </div>
  )
}

export function EmptyState({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className="state state--empty">
      <p className="state-title">{title}</p>
      {children}
    </div>
  )
}

export function CardSkeletons({ count = 6 }: { count?: number }) {
  return (
    <div className="grid" aria-hidden="true">
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="card card--skeleton">
          <div className="skeleton skeleton--art" />
          <div className="card-body">
            <div className="skeleton skeleton--line" style={{ width: '40%' }} />
            <div className="skeleton skeleton--line" style={{ width: '75%' }} />
            <div className="skeleton skeleton--line" style={{ width: '90%' }} />
          </div>
        </div>
      ))}
    </div>
  )
}
