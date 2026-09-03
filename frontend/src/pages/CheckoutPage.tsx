import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'

import { EmptyState, Loading } from '../components/States'
import { api } from '../lib/api'
import { useCart } from '../lib/cart'
import { formatMoney } from '../lib/format'

const FIELDS = [
  { name: 'customer_name', label: 'Full name', autoComplete: 'name', type: 'text' },
  { name: 'email', label: 'Email', autoComplete: 'email', type: 'email' },
  { name: 'address', label: 'Address', autoComplete: 'street-address', type: 'text' },
  { name: 'city', label: 'City', autoComplete: 'address-level2', type: 'text' },
  { name: 'postal_code', label: 'Postal code', autoComplete: 'postal-code', type: 'text' },
  { name: 'country', label: 'Country', autoComplete: 'country-name', type: 'text' },
] as const

type FormState = Record<(typeof FIELDS)[number]['name'] | 'note', string>

const EMPTY: FormState = {
  customer_name: '',
  email: '',
  address: '',
  city: '',
  postal_code: '',
  country: '',
  note: '',
}

export function CheckoutPage() {
  const { cart, loading, forget } = useCart()
  const navigate = useNavigate()
  const [form, setForm] = useState<FormState>(EMPTY)
  const [busy, setBusy] = useState(false)
  const [failure, setFailure] = useState<string | null>(null)

  if (loading) return <Loading />
  if (!cart || cart.items.length === 0) {
    return (
      <section className="shell section">
        <h1>Checkout</h1>
        <EmptyState title="There is nothing to check out.">
          <Link to="/" className="btn btn--primary">
            Back to the shop
          </Link>
        </EmptyState>
      </section>
    )
  }

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault()
    if (!cart) return
    setBusy(true)
    setFailure(null)
    try {
      const order = await api.checkout({ cart_id: cart.id, ...form })
      // The API consumed the cart, so drop the stale id before navigating.
      forget()
      navigate(`/order/${order.number}`, { replace: true })
    } catch (err) {
      setFailure(err instanceof Error ? err.message : 'Checkout failed')
      setBusy(false)
    }
  }

  return (
    <section className="shell section">
      <h1>Checkout</h1>
      <p className="lede">
        Nothing is charged and nothing is shipped. The order is written to Postgres so you can see
        the whole path work end to end.
      </p>

      <div className="cart-layout">
        <form className="form" onSubmit={onSubmit} noValidate>
          <div className="form-grid">
            {FIELDS.map((field) => (
              <label key={field.name} className={`field field--stacked`}>
                <span>{field.label}</span>
                <input
                  type={field.type}
                  name={field.name}
                  autoComplete={field.autoComplete}
                  required
                  value={form[field.name]}
                  onChange={(e) => setForm({ ...form, [field.name]: e.target.value })}
                />
              </label>
            ))}
            <label className="field field--stacked field--wide">
              <span>Delivery note (optional)</span>
              <textarea
                name="note"
                rows={3}
                maxLength={500}
                value={form.note}
                onChange={(e) => setForm({ ...form, note: e.target.value })}
              />
            </label>
          </div>

          {failure && (
            <p className="notice notice--error" role="alert">
              {failure}
            </p>
          )}

          <button type="submit" className="btn btn--primary" disabled={busy}>
            {busy ? 'Placing order...' : `Place order - ${formatMoney(cart.total_cents)}`}
          </button>
        </form>

        <aside className="summary">
          <h2>Order summary</h2>
          <ul className="summary-lines">
            {cart.items.map((item) => (
              <li key={item.id}>
                <span>
                  {item.quantity} x {item.product.name}
                </span>
                <span>{formatMoney(item.line_total_cents)}</span>
              </li>
            ))}
          </ul>
          <dl>
            <div>
              <dt>Subtotal</dt>
              <dd>{formatMoney(cart.subtotal_cents)}</dd>
            </div>
            <div>
              <dt>Shipping</dt>
              <dd>{cart.shipping_cents === 0 ? 'Free' : formatMoney(cart.shipping_cents)}</dd>
            </div>
            <div className="summary-total">
              <dt>Total</dt>
              <dd>{formatMoney(cart.total_cents)}</dd>
            </div>
          </dl>
        </aside>
      </div>
    </section>
  )
}
