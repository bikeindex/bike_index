import { FILTERS, toQuery } from 'bikebook/query'

const LOGGED = [...FILTERS, 'vehicle_models', 'q', 'count']
// A search is what it asks for, apart from its order and the jurisdiction whose classes it shows
const SEARCHED = LOGGED.filter((name) => !['jurisdiction', 'year_dir', 'price_dir', 'count'].includes(name))
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
    const pick = (names) => toQuery(Object.fromEntries(names.map((name) => [name, params[name]])))
    const search = pick(SEARCHED)
    if (!search || search === this.#sent) return

    this.#sent = search
    const query = pick(LOGGED)
    fetch(`${this.#path}?${query}`, { keepalive: true }).catch(() => {})
    window.dataLayer?.push({ event: 'bikebook_search', bikebook_search: query })
  }
}
