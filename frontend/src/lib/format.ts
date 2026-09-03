const money = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 2,
})

export function formatMoney(cents: number): string {
  return money.format(cents / 100)
}

export function formatSize(width: number | null, height: number | null): string | null {
  if (!width || !height) return null
  return `${width} x ${height} mm`
}

const SURFACE_LABELS: Record<string, string> = {
  chalk: 'Chalk',
  'dry-erase': 'Dry-erase',
  glass: 'Glass',
  cork: 'Cork',
  paper: 'Paper',
  none: 'Accessory',
}

export function surfaceLabel(surface: string): string {
  return SURFACE_LABELS[surface] ?? surface
}

export function formatDate(iso: string): string {
  return new Date(iso).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })
}

export function formatUptime(seconds: number): string {
  if (seconds < 60) return `${Math.round(seconds)}s`
  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${minutes}m ${Math.round(seconds % 60)}s`
  const hours = Math.floor(minutes / 60)
  return `${hours}h ${minutes % 60}m`
}

/** "Glass boards - Glass" for a board, just the category for an accessory. */
export function productKicker(categoryName: string, surface: string): string {
  return surface === 'none' ? categoryName : `${categoryName} \u00b7 ${surfaceLabel(surface)}`
}
