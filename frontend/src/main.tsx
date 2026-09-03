import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'

import { App } from './App'
import { CartProvider } from './lib/cart'
import { loadRuntimeConfig } from './lib/config'
import './styles.css'

// Resolve the API origin before the first render so no component has to wait on it.
loadRuntimeConfig().finally(() => {
  createRoot(document.getElementById('root')!).render(
    <StrictMode>
      <BrowserRouter>
        <CartProvider>
          <App />
        </CartProvider>
      </BrowserRouter>
    </StrictMode>,
  )
})
