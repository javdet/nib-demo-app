export interface Category {
  slug: string
  name: string
  tagline: string
}

export type Surface = 'chalk' | 'dry-erase' | 'glass' | 'cork' | 'paper' | 'none'

export interface Product {
  id: number
  slug: string
  name: string
  surface: Surface
  price_cents: number
  width_mm: number | null
  height_mm: number | null
  summary: string
  description: string
  stock: number
  featured: boolean
  accent: string
  category: Category
}

export interface ProductPage {
  items: Product[]
  total: number
  page: number
  page_size: number
  pages: number
}

export interface CartItem {
  id: number
  quantity: number
  line_total_cents: number
  product: Product
}

export interface Cart {
  id: string
  items: CartItem[]
  item_count: number
  subtotal_cents: number
  shipping_cents: number
  total_cents: number
  free_shipping_threshold_cents: number
}

export interface OrderItem {
  product_slug: string
  product_name: string
  unit_price_cents: number
  quantity: number
}

export interface Order {
  number: string
  status: string
  customer_name: string
  email: string
  address: string
  city: string
  postal_code: string
  country: string
  note: string
  subtotal_cents: number
  shipping_cents: number
  total_cents: number
  created_at: string
  items: OrderItem[]
}

export interface CheckoutPayload {
  cart_id: string
  customer_name: string
  email: string
  address: string
  city: string
  postal_code: string
  country: string
  note: string
}

export interface DatabaseMeta {
  dialect: string
  host: string
  name: string
  reachable: boolean
  latency_ms: number | null
  error: string | null
}

export interface Meta {
  service: string
  version: string
  git_sha: string
  environment: string
  region: string
  served_by: string
  task_id: string | null
  uptime_seconds: number
  served_at: string
  database: DatabaseMeta
}
