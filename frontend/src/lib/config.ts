/**
 * Runtime configuration.
 *
 * The bundle is uploaded to S3 once and served by CloudFront to every
 * environment, so the API origin must not be baked in at build time. `main.tsx`
 * fetches `/config.json` before rendering; a build-time `VITE_API_BASE_URL` and
 * finally same-origin `/api` are the fallbacks.
 */

export interface RuntimeConfig {
  apiBaseUrl: string
}

let config: RuntimeConfig = {
  apiBaseUrl: import.meta.env.VITE_API_BASE_URL ?? '',
}

export function getConfig(): RuntimeConfig {
  return config
}

export function apiUrl(path: string): string {
  const base = config.apiBaseUrl.replace(/\/$/, '')
  return `${base}/api${path}`
}

export async function loadRuntimeConfig(): Promise<RuntimeConfig> {
  try {
    const response = await fetch('/config.json', { cache: 'no-store' })
    if (response.ok) {
      const body = (await response.json()) as Partial<RuntimeConfig>
      if (typeof body.apiBaseUrl === 'string') {
        config = { ...config, apiBaseUrl: body.apiBaseUrl }
      }
    }
  } catch {
    // No config.json (or CloudFront returned the SPA shell) - keep the fallback.
  }
  return config
}
