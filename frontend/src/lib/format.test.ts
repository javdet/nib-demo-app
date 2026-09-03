import { describe, expect, it } from 'vitest'

import { formatMoney, formatSize, formatUptime, productKicker, surfaceLabel } from './format'
import { apiUrl } from './config'

describe('formatMoney', () => {
  it('renders integer cents as currency', () => {
    expect(formatMoney(12900)).toBe('$129.00')
    expect(formatMoney(0)).toBe('$0.00')
    expect(formatMoney(5)).toBe('$0.05')
  })
})

describe('formatSize', () => {
  it('formats a pair of dimensions', () => {
    expect(formatSize(900, 600)).toBe('900 x 600 mm')
  })

  it('returns null for accessories with no dimensions', () => {
    expect(formatSize(null, null)).toBeNull()
    expect(formatSize(900, null)).toBeNull()
  })
})

describe('surfaceLabel', () => {
  it('maps known surfaces and passes unknown ones through', () => {
    expect(surfaceLabel('dry-erase')).toBe('Dry-erase')
    expect(surfaceLabel('none')).toBe('Accessory')
    expect(surfaceLabel('marble')).toBe('marble')
  })
})

describe('formatUptime', () => {
  it('scales the unit to the magnitude', () => {
    expect(formatUptime(42)).toBe('42s')
    expect(formatUptime(125)).toBe('2m 5s')
    expect(formatUptime(7325)).toBe('2h 2m')
  })
})

describe('apiUrl', () => {
  it('defaults to a same-origin /api prefix', () => {
    expect(apiUrl('/products')).toBe('/api/products')
  })
})

describe('productKicker', () => {
  it('pairs the category with the surface for boards', () => {
    expect(productKicker('Glass boards', 'glass')).toBe('Glass boards · Glass')
  })

  it('drops the redundant surface for accessories', () => {
    expect(productKicker('Accessories', 'none')).toBe('Accessories')
  })
})
