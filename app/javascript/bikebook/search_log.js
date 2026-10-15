import { FILTERS } from 'bikebook/hydrate'
import { toQuery } from 'bikebook/query'

const LOGGED = [...FILTERS, 'vehicle_models', 'q', 'count']
// on their own, the market, jurisdiction and sorts are any visit's
const SEARCHED = LOGGED.filter((name) => !['market', 'jurisdiction', 'year_dir', 'price_dir', 'count'].includes(name))
const SETTLE_MS = 1000

// Reports the searches the browser runs to the server's search logs, a typed one once it settles
// rather than at each keystroke
export class SearchLog {
  #path
  #pending
  #sent
  #timer

  constructor (path) {
    this.#path = path
  }

  typed (params) {
    clearTimeout(this.#timer)
    this.#pending = params
    this.#timer = setTimeout(() => this.#flush(), SETTLE_MS)
  }

  // after the typing that found what it picks
  visited (url) {
    this.#flush()
    this.#send(Object.fromEntries(url.searchParams))
  }

  #flush () {
    clearTimeout(this.#timer)
    if (this.#pending) this.#send(this.#pending)
    this.#pending = undefined
  }

  #send (params) {
    const logged = Object.fromEntries(LOGGED.map((name) => [name, params[name]]))
    if (!SEARCHED.some((name) => String(logged[name] ?? '').trim())) return

    const query = toQuery(logged)
    if (query === this.#sent) return
    this.#sent = query
    fetch(`${this.#path}?${query}`, { keepalive: true }).catch(() => {})
    window.dataLayer?.push({ event: 'bikebook_search', bikebook_search: query })
  }
}
