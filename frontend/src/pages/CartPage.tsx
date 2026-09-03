import { Link } from 'react-router-dom'

import { BoardArt } from '../components/BoardArt'
import { QuantityStepper } from '../components/QuantityStepper'
import { EmptyState, Loading } from '../components/States'
import { useCart } from '../lib/cart'
import { formatMoney } from '../lib/format'

export function CartPage() {
  const { cart, loading, error, setQuantity, remove } = useCart()

  if (loading) return <Loading label="Opening your cart..." />

  if (!cart || cart.items.length === 0) {
    return (
      <section className="shell section">
        <h1>Your cart</h1>
        <EmptyState title="Nothing in the cart yet.">
          <Link to="/" className="btn btn--primary">
            Browse the boards
          </Link>
        </EmptyState>
      </section>
    )
  }

  const remaining = cart.free_shipping_threshold_cents - cart.subtotal_cents

  return (
    <section className="shell section">
      <h1>Your cart</h1>
      {error && (
        <p className="notice notice--error" role="alert">
          {error}
        </p>
      )}

      <div className="cart-layout">
        <ul className="cart-lines">
          {cart.items.map((item) => (
            <li key={item.id} className="cart-line">
              <Link to={`/product/${item.product.slug}`} className="cart-line-art">
                <BoardArt product={item.product} className="art" />
              </Link>
              <div className="cart-line-body">
                <h2>
                  <Link to={`/product/${item.product.slug}`}>{item.product.name}</Link>
                </h2>
                <p className="muted small">{item.product.category.name}</p>
                <p className="muted small">{formatMoney(item.product.price_cents)} each</p>
                <div className="cart-line-actions">
                  <QuantityStepper
                    value={item.quantity}
                    max={item.product.stock}
                    onChange={(v) => void setQuantity(item.id, v)}
                    label={`Quantity of ${item.product.name}`}
                  />
                  <button
                    type="button"
                    className="link-button"
                    onClick={() => void remove(item.id)}
                  >
                    Remove
                  </button>
                </div>
              </div>
              <p className="cart-line-total">{formatMoney(item.line_total_cents)}</p>
            </li>
          ))}
        </ul>

        <aside className="summary">
          <h2>Summary</h2>
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

          {remaining > 0 && (
            <p className="muted small">
              {formatMoney(remaining)} more for free shipping.
            </p>
          )}

          <Link to="/checkout" className="btn btn--primary btn--block">
            Checkout
          </Link>
          <p className="muted small">
            Cart <code>{cart.id.slice(0, 8)}</code> lives in Postgres, not in your browser.
          </p>
        </aside>
      </div>
    </section>
  )
}
