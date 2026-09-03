import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'

import { BoardArt } from '../components/BoardArt'
import { QuantityStepper } from '../components/QuantityStepper'
import { ErrorState, Loading } from '../components/States'
import { api } from '../lib/api'
import { useCart } from '../lib/cart'
import { formatMoney, formatSize, productKicker, surfaceLabel } from '../lib/format'
import { useAsync } from '../lib/useAsync'

export function ProductPage() {
  const { slug = '' } = useParams()
  const { data: product, error, loading, reload } = useAsync(() => api.product(slug), [slug])
  const { add } = useCart()

  const [quantity, setQuantity] = useState(1)
  const [busy, setBusy] = useState(false)
  const [added, setAdded] = useState(false)
  const [failure, setFailure] = useState<string | null>(null)

  if (loading) return <Loading label="Fetching the board..." />
  if (error) return <ErrorState message={error} onRetry={reload} />
  if (!product) return null

  const size = formatSize(product.width_mm, product.height_mm)

  async function onAdd() {
    if (!product) return
    setBusy(true)
    setFailure(null)
    try {
      await add(product.id, quantity)
      setAdded(true)
      setTimeout(() => setAdded(false), 2500)
    } catch (err) {
      setFailure(err instanceof Error ? err.message : 'Could not add to cart')
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="shell section">
      <nav className="breadcrumbs" aria-label="Breadcrumb">
        <Link to="/">Shop</Link>
        <span aria-hidden="true">/</span>
        <Link to={`/?category=${product.category.slug}`}>{product.category.name}</Link>
        <span aria-hidden="true">/</span>
        <span aria-current="page">{product.name}</span>
      </nav>

      <div className="detail">
        <div className="detail-art">
          <BoardArt product={product} className="art art--large" />
        </div>

        <div className="detail-body">
          <p className="card-eyebrow">
            {productKicker(product.category.name, product.surface)}
          </p>
          <h1>{product.name}</h1>
          <p className="lede">{product.summary}</p>
          <p className="detail-price">{formatMoney(product.price_cents)}</p>

          <dl className="spec">
            {size && (
              <div>
                <dt>Size</dt>
                <dd>{size}</dd>
              </div>
            )}
            {product.surface !== 'none' && (
              <div>
                <dt>Surface</dt>
                <dd>{surfaceLabel(product.surface)}</dd>
              </div>
            )}
            <div>
              <dt>Availability</dt>
              <dd>{product.stock > 0 ? `${product.stock} in stock` : 'Out of stock'}</dd>
            </div>
          </dl>

          {product.stock > 0 ? (
            <div className="buy">
              <QuantityStepper
                value={quantity}
                max={product.stock}
                onChange={(v) => setQuantity(Math.max(1, v))}
              />
              <button type="button" className="btn btn--primary" onClick={onAdd} disabled={busy}>
                {busy ? 'Adding...' : added ? 'Added to cart' : 'Add to cart'}
              </button>
              {added && (
                <Link to="/cart" className="btn btn--ghost">
                  View cart
                </Link>
              )}
            </div>
          ) : (
            <p className="notice">This one is out of stock. Nothing is restocked in a demo.</p>
          )}

          {failure && (
            <p className="notice notice--error" role="alert">
              {failure}
            </p>
          )}

          <div className="prose">
            <p>{product.description}</p>
          </div>
        </div>
      </div>
    </section>
  )
}
