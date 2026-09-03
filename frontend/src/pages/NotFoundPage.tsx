import { Link } from 'react-router-dom'

export function NotFoundPage() {
  return (
    <section className="shell section section--narrow">
      <h1>Wiped clean</h1>
      <p className="lede">
        Nothing is written on this part of the board. Someone got to it with the eraser first.
      </p>
      <Link to="/" className="btn btn--primary">
        Back to the shop
      </Link>
    </section>
  )
}
