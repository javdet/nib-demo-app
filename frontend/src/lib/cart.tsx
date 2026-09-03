import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'

import { ApiError, api } from './api'
import type { Cart } from './types'

const STORAGE_KEY = 'nib-shop.cart-id'

interface CartContextValue {
  cart: Cart | null
  loading: boolean
  error: string | null
  itemCount: number
  add: (productId: number, quantity?: number) => Promise<void>
  setQuantity: (itemId: number, quantity: number) => Promise<void>
  remove: (itemId: number) => Promise<void>
  forget: () => void
}

const CartContext = createContext<CartContextValue | null>(null)

function readStoredId(): string | null {
  try {
    return window.localStorage.getItem(STORAGE_KEY)
  } catch {
    return null
  }
}

function storeId(id: string | null): void {
  try {
    if (id) window.localStorage.setItem(STORAGE_KEY, id)
    else window.localStorage.removeItem(STORAGE_KEY)
  } catch {
    // Private browsing: the cart simply will not survive a reload.
  }
}

export function CartProvider({ children }: { children: ReactNode }) {
  const [cart, setCart] = useState<Cart | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  // Rehydrate the server-side cart from the id in localStorage. The browser
  // stores nothing but that id; prices and stock always come from Postgres.
  useEffect(() => {
    const id = readStoredId()
    if (!id) {
      setLoading(false)
      return
    }
    let cancelled = false
    api
      .cart(id)
      .then((loaded) => {
        if (!cancelled) setCart(loaded)
      })
      .catch((err: ApiError) => {
        // A cart that was checked out (or expired) is gone: start clean.
        if (err.status === 404) storeId(null)
        else if (!cancelled) setError(err.message)
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [])

  const ensureCart = useCallback(async (): Promise<Cart> => {
    if (cart) return cart
    const created = await api.createCart()
    storeId(created.id)
    setCart(created)
    return created
  }, [cart])

  const run = useCallback(async (action: () => Promise<Cart>) => {
    setError(null)
    try {
      setCart(await action())
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Something went wrong')
      throw err
    }
  }, [])

  const add = useCallback(
    async (productId: number, quantity = 1) => {
      const current = await ensureCart()
      await run(() => api.addToCart(current.id, productId, quantity))
    },
    [ensureCart, run],
  )

  const setQuantity = useCallback(
    async (itemId: number, quantity: number) => {
      if (!cart) return
      await run(() => api.setQuantity(cart.id, itemId, quantity))
    },
    [cart, run],
  )

  const remove = useCallback(
    async (itemId: number) => {
      if (!cart) return
      await run(() => api.removeItem(cart.id, itemId))
    },
    [cart, run],
  )

  const forget = useCallback(() => {
    storeId(null)
    setCart(null)
    setError(null)
  }, [])

  const value = useMemo<CartContextValue>(
    () => ({
      cart,
      loading,
      error,
      itemCount: cart?.item_count ?? 0,
      add,
      setQuantity,
      remove,
      forget,
    }),
    [cart, loading, error, add, setQuantity, remove, forget],
  )

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>
}

// eslint-disable-next-line react-refresh/only-export-components
export function useCart(): CartContextValue {
  const context = useContext(CartContext)
  if (!context) throw new Error('useCart must be used inside <CartProvider>')
  return context
}
