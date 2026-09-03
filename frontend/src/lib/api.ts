import { apiUrl } from './config'
import type {
  Cart,
  Category,
  CheckoutPayload,
  Meta,
  Order,
  Product,
  ProductPage,
} from './types'

export class ApiError extends Error {
  readonly status: number

  constructor(status: number, message: string) {
    super(message)
    this.name = 'ApiError'
    this.status = status
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let response: Response
  try {
    response = await fetch(apiUrl(path), {
      ...init,
      headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
    })
  } catch {
    throw new ApiError(0, 'Cannot reach the API. Is the backend running?')
  }

  if (!response.ok) {
    throw new ApiError(response.status, await errorMessage(response))
  }
  if (response.status === 204) return undefined as T
  return (await response.json()) as T
}

async function errorMessage(response: Response): Promise<string> {
  try {
    const body = await response.json()
    const detail = body?.detail
    if (typeof detail === 'string') return detail
    // FastAPI validation errors arrive as a list of {loc, msg}.
    if (Array.isArray(detail) && detail.length > 0) {
      return detail.map((d: { msg?: string }) => d.msg ?? 'invalid value').join(', ')
    }
  } catch {
    // fall through to the generic message
  }
  return `Request failed (${response.status})`
}

export interface ProductQuery {
  category?: string
  surface?: string
  q?: string
  in_stock?: boolean
  sort?: string
  page?: number
  page_size?: number
}

export const api = {
  categories: () => request<Category[]>('/categories'),

  products: (query: ProductQuery = {}) => {
    const params = new URLSearchParams()
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined && value !== '' && value !== false) {
        params.set(key, String(value))
      }
    }
    const qs = params.toString()
    return request<ProductPage>(`/products${qs ? `?${qs}` : ''}`)
  },

  product: (slug: string) => request<Product>(`/products/${slug}`),

  createCart: () => request<Cart>('/carts', { method: 'POST' }),
  cart: (id: string) => request<Cart>(`/carts/${id}`),
  addToCart: (cartId: string, productId: number, quantity = 1) =>
    request<Cart>(`/carts/${cartId}/items`, {
      method: 'POST',
      body: JSON.stringify({ product_id: productId, quantity }),
    }),
  setQuantity: (cartId: string, itemId: number, quantity: number) =>
    request<Cart>(`/carts/${cartId}/items/${itemId}`, {
      method: 'PATCH',
      body: JSON.stringify({ quantity }),
    }),
  removeItem: (cartId: string, itemId: number) =>
    request<Cart>(`/carts/${cartId}/items/${itemId}`, { method: 'DELETE' }),

  checkout: (payload: CheckoutPayload) =>
    request<Order>('/orders', { method: 'POST', body: JSON.stringify(payload) }),
  order: (number: string) => request<Order>(`/orders/${number}`),

  meta: () => request<Meta>('/meta'),
}
