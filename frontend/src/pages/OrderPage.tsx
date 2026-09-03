import { Link, useParams } from 'react-router-dom'

import { CheckIcon } from '../components/Icons'
import { ErrorState, Loading } from '../components/States'
import { api } from '../lib/api'
import { formatDate, formatMoney } from '../lib/format'
import { useAsync } from '../lib/useAsync'

export function OrderPage() {
  const { number = '' } = useParams()
  const { data: order, error, loading, reload } = useAsync(() => api.order(number), [number])

  if (loading) return <Loading label="Looking up the order..." />
  if (error) return <ErrorState message={error} onRetry={reload} />
  if (!order) return null

  return (
    <section className="shell section section--narrow">
      <div className="order-head">
        <span className="order-check">
          <CheckIcon size={24} />
        </span>
        <div>
          <h1>Order {order.number}</h1>
          <p className="muted">
            Placed {formatDate(order.created_at)} &middot; {order.status}
          </p>
        </div>
      </div>

      <p className="lede">
        Thanks, {order.customer_name.split(' ')[0]}. This order now exists as a row in Postgres -
        reload the page, or open <code>/order/{order.number}</code> on another device, and the API
        will read it straight back.
      </p>

      <div className="panel">
        <h2>What you ordered</h2>
        <ul className="summary-lines">
          {order.items.map((item) => (
            <li key={item.product_slug}>
              <span>
                {item.quantity} x{' '}
                <Link to={`/product/${item.product_slug}`}>{item.product_name}</Link>
              </span>
              <span>{formatMoney(item.unit_price_cents * item.quantity)}</span>
            </li>
          ))}
        </ul>
        <dl className="order-totals">
          <div>
            <dt>Subtotal</dt>
            <dd>{formatMoney(order.subtotal_cents)}</dd>
          </div>
          <div>
            <dt>Shipping</dt>
            <dd>{order.shipping_cents === 0 ? 'Free' : formatMoney(order.shipping_cents)}</dd>
          </div>
          <div className="summary-total">
            <dt>Total</dt>
            <dd>{formatMoney(order.total_cents)}</dd>
          </div>
        </dl>
      </div>

      <div className="panel">
        <h2>Shipping to</h2>
        <address>
          {order.customer_name}
          <br />
          {order.address}
          <br />
          {order.city} {order.postal_code}
          <br />
          {order.country}
        </address>
        {order.note && <p className="muted small">Note: {order.note}</p>}
      </div>

      <Link to="/" className="btn btn--ghost">
        Back to the shop
      </Link>
    </section>
  )
}
