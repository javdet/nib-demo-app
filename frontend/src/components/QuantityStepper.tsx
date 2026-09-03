interface Props {
  value: number
  max: number
  onChange: (value: number) => void
  disabled?: boolean
  label?: string
}

export function QuantityStepper({ value, max, onChange, disabled, label = 'Quantity' }: Props) {
  return (
    <div className="stepper" role="group" aria-label={label}>
      <button
        type="button"
        onClick={() => onChange(value - 1)}
        disabled={disabled || value <= 0}
        aria-label="Decrease quantity"
      >
        &minus;
      </button>
      <span aria-live="polite">{value}</span>
      <button
        type="button"
        onClick={() => onChange(value + 1)}
        disabled={disabled || value >= max}
        aria-label="Increase quantity"
      >
        +
      </button>
    </div>
  )
}
