import { useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'

import { CardSkeletons, EmptyState, ErrorState } from '../components/States'
import { ProductCard } from '../components/ProductCard'
import { api } from '../lib/api'
import { surfaceLabel } from '../lib/format'
import { useAsync } from '../lib/useAsync'

const SURFACES = ['chalk', 'dry-erase', 'glass', 'cork', 'paper', 'none']
const SORTS = [
  { value: 'featured', label: 'Featured' },
  { value: 'price_asc', label: 'Price, low to high' },
  { value: 'price_desc', label: 'Price, high to low' },
  { value: 'name', label: 'Name' },
]
const PAGE_SIZE = 9

export function CatalogPage() {
  const [params, setParams] = useSearchParams()

  const category = params.get('category') ?? ''
  const surface = params.get('surface') ?? ''
  const sort = params.get('sort') ?? 'featured'
  const inStock = params.get('in_stock') === '1'
  const query = params.get('q') ?? ''
  const page = Number(params.get('page') ?? '1')

  // Keep the input responsive while the request is debounced behind it.
  const [searchDraft, setSearchDraft] = useState(query)
  useEffect(() => setSearchDraft(query), [query])
  useEffect(() => {
    if (searchDraft === query) return
    const timer = setTimeout(() => update({ q: searchDraft || null, page: null }), 300)
    return () => clearTimeout(timer)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [searchDraft])

  function update(changes: Record<string, string | null>) {
    const next = new URLSearchParams(params)
    for (const [key, value] of Object.entries(changes)) {
      if (value === null || value === '') next.delete(key)
      else next.set(key, value)
    }
    setParams(next, { replace: true })
  }

  const categories = useAsync(() => api.categories(), [])
  const products = useAsync(
    () =>
      api.products({
        category: category || undefined,
        surface: surface || undefined,
        q: query || undefined,
        in_stock: inStock,
        sort,
        page,
        page_size: PAGE_SIZE,
      }),
    [category, surface, query, inStock, sort, page],
  )

  const activeCategory = categories.data?.find((c) => c.slug === category)

  return (
    <>
      <section className="hero">
        <div className="shell hero-inner">
          <p className="eyebrow">Since the first standup that needed a diagram</p>
          <h1>
            Boards that hold a thought <em>longer than a browser tab</em>
          </h1>
          <p className="lede">
            Slate, porcelain, glass and cork - cut, framed and shipped for people who work out
            loud. Everything on this page is served by a containerised API reading a Postgres
            catalogue.
          </p>
        </div>
      </section>

      <section className="shell section">
        <div className="filters">
          <div className="chips" role="group" aria-label="Category">
            <button
              type="button"
              className={`chip ${category === '' ? 'chip--on' : ''}`}
              onClick={() => update({ category: null, page: null })}
            >
              Everything
            </button>
            {categories.data?.map((c) => (
              <button
                key={c.slug}
                type="button"
                className={`chip ${category === c.slug ? 'chip--on' : ''}`}
                onClick={() => update({ category: c.slug, page: null })}
              >
                {c.name}
              </button>
            ))}
          </div>

          <div className="filter-row">
            <label className="field">
              <span className="sr-only">Search</span>
              <input
                type="search"
                placeholder="Search boards, chalk, glass..."
                value={searchDraft}
                onChange={(e) => setSearchDraft(e.target.value)}
              />
            </label>

            <label className="field">
              <span className="sr-only">Surface</span>
              <select
                value={surface}
                onChange={(e) => update({ surface: e.target.value || null, page: null })}
              >
                <option value="">Any surface</option>
                {SURFACES.map((s) => (
                  <option key={s} value={s}>
                    {surfaceLabel(s)}
                  </option>
                ))}
              </select>
            </label>

            <label className="field">
              <span className="sr-only">Sort</span>
              <select value={sort} onChange={(e) => update({ sort: e.target.value, page: null })}>
                {SORTS.map((s) => (
                  <option key={s.value} value={s.value}>
                    {s.label}
                  </option>
                ))}
              </select>
            </label>

            <label className="toggle">
              <input
                type="checkbox"
                checked={inStock}
                onChange={(e) => update({ in_stock: e.target.checked ? '1' : null, page: null })}
              />
              <span>In stock only</span>
            </label>
          </div>
        </div>

        {activeCategory && <p className="category-tagline">{activeCategory.tagline}</p>}

        {products.loading && <CardSkeletons count={PAGE_SIZE} />}
        {products.error && <ErrorState message={products.error} onRetry={products.reload} />}

        {products.data && !products.loading && (
          <>
            <p className="result-count muted">
              {products.data.total} {products.data.total === 1 ? 'product' : 'products'}
              {query && <> matching &ldquo;{query}&rdquo;</>}
            </p>

            {products.data.items.length === 0 ? (
              <EmptyState title="Nothing matches those filters.">
                <button
                  type="button"
                  className="btn btn--ghost"
                  onClick={() => setParams(new URLSearchParams(), { replace: true })}
                >
                  Clear filters
                </button>
              </EmptyState>
            ) : (
              <div className="grid">
                {products.data.items.map((product) => (
                  <ProductCard key={product.id} product={product} />
                ))}
              </div>
            )}

            {products.data.pages > 1 && (
              <nav className="pagination" aria-label="Pagination">
                <button
                  type="button"
                  className="btn btn--ghost"
                  disabled={page <= 1}
                  onClick={() => update({ page: String(page - 1) })}
                >
                  Previous
                </button>
                <span className="muted">
                  Page {products.data.page} of {products.data.pages}
                </span>
                <button
                  type="button"
                  className="btn btn--ghost"
                  disabled={page >= products.data.pages}
                  onClick={() => update({ page: String(page + 1) })}
                >
                  Next
                </button>
              </nav>
            )}
          </>
        )}
      </section>
    </>
  )
}
