import { Link, NavLink, Outlet } from 'react-router-dom'

import { useCart } from '../lib/cart'
import { CartIcon, NibMark } from './Icons'
import { DeploymentStrip } from './DeploymentStrip'

export function Layout() {
  const { itemCount } = useCart()

  return (
    <div className="app">
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="site-header">
        <div className="shell header-inner">
          <Link to="/" className="brand">
            <span className="brand-mark">
              <NibMark />
            </span>
            <span className="brand-text">
              <strong>Nib &amp; Slate</strong>
              <small>Surfaces worth drawing on</small>
            </span>
          </Link>

          <nav className="site-nav" aria-label="Main">
            <NavLink to="/" end>
              Shop
            </NavLink>
            <NavLink to="/deployment">How it&apos;s deployed</NavLink>
          </nav>

          <Link to="/cart" className="cart-link" aria-label={`Cart, ${itemCount} items`}>
            <CartIcon />
            <span>Cart</span>
            {itemCount > 0 && <span className="cart-badge">{itemCount}</span>}
          </Link>
        </div>
      </header>

      <main id="main">
        <Outlet />
      </main>

      <footer className="site-footer">
        <div className="shell footer-inner">
          <div>
            <p className="footer-title">Nib &amp; Slate</p>
            <p className="muted">
              A demonstration storefront. Nothing ships, no card is charged, and every board is
              drawn by the browser.
            </p>
          </div>
          <DeploymentStrip />
        </div>
      </footer>
    </div>
  )
}
