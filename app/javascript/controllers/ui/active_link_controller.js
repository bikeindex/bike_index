import { Controller } from '@hotwired/stimulus'

// Rails' current_page? ignores a trailing slash on either side
const trimSlash = (path) => path.length > 1 ? path.replace(/\/$/, '') : path

const controllerOf = (route) => route.split('#')[0]

// UI::ActiveLink::Component::ROUTE_MATCHES — the rest compare the URL
const ROUTE_MATCHES = ['controller', 'controller_action']

// Connects to data-controller='ui--active-link'
// Renders UI::ActiveLink::Component's aria-current, which the server can't: these links are
// cached fragments, so the markup is shared by every page it was rendered for.
export default class extends Controller {
  static values = { match: String, routes: String, query: Object }

  connect () {
    if (!this.isActive()) return this.element.removeAttribute('aria-current')

    this.element.setAttribute('aria-current', this.ariaCurrent())
    // Announced for a menu that has to react to which of its links is the current one --
    // a collapsed section opening around it. Fired from connect, which for a link runs
    // after its ancestors', so a listener up the tree is already wired
    this.dispatch('current')
  }

  get routeMatch () {
    return ROUTE_MATCHES.includes(this.matchValue)
  }

  get queryMatch () {
    return this.matchValue === 'query'
  }

  // "page" is reserved for the link whose own URL is the current one. A widened match means
  // the current page sits inside what the link points at, not that it is it -- aria-current's
  // "true", so a reader isn't told a link elsewhere is where it already is
  ariaCurrent () {
    return (this.routeMatch || this.queryMatch) ? 'true' : 'page'
  }

  isActive () {
    if (this.queryMatch) return this.queryMatches()

    return this.routeMatch ? this.routeMatches() : this.pathMatches()
  }

  // Mirrors current_page?: the query string counts when the link carries one, so a search
  // link stays active on page 2. full_path counts it either way.
  pathMatches () {
    const url = new URL(this.element.href, window.location.href)
    // Off-site, the page can never be what the link points at
    if (url.origin !== window.location.origin) return false
    if (url.search || this.matchValue === 'full_path') {
      return url.pathname + url.search === window.location.pathname + window.location.search
    }

    return trimSlash(url.pathname) === trimSlash(window.location.pathname)
  }

  // The entry already in force links away from itself, to clear the filter, so its own href
  // can't be what's compared -- only the params it names, with '' for one the URL leaves out
  queryMatches () {
    const current = new URLSearchParams(window.location.search)

    return Object.entries(this.queryValue)
      .every(([param, values]) => values.includes(current.get(param) ?? ''))
  }

  // The page's route comes off the body, since only the server can resolve one. A link whose
  // own path didn't resolve renders no routes, and matches nothing rather than falling back.
  routeMatches () {
    const pageRoute = document.body.dataset.pageRoute
    if (!pageRoute || !this.hasRoutesValue) return false

    return this.routesValue.split(' ')
      .includes(this.matchValue === 'controller_action' ? pageRoute : controllerOf(pageRoute))
  }
}
