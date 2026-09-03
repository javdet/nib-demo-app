import { Link } from 'react-router-dom'

import { formatMoney, formatSize, productKicker } from '../lib/format'
import type { Product } from '../lib/types'
import { BoardArt } from './BoardArt'

export function ProductCard({ product }: { product: Product }) {
  const size = formatSize(product.width_mm, product.height_mm)

  return (
    <article className="card">
      <Link to={`/product/${product.slug}`} className="card-art">
        <BoardArt product={product} className="art" />
        {product.stock === 0 && <span className="pill pill--muted">Out of stock</span>}
        {product.featured && product.stock > 0 && <span className="pill">Staff pick</span>}
      </Link>
      <div className="card-body">
        <p className="card-eyebrow">{productKicker(product.category.name, product.surface)}</p>
        <h3 className="card-title">
          <Link to={`/product/${product.slug}`}>{product.name}</Link>
        </h3>
        <p className="card-summary">{product.summary}</p>
        <div className="card-foot">
          <span className="price">{formatMoney(product.price_cents)}</span>
          {size && <span className="muted small">{size}</span>}
        </div>
      </div>
    </article>
  )
}
