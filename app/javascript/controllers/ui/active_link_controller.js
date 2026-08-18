import { Controller } from '@hotwired/stimulus'

// Rails' current_page? ignores a trailing slash on either side
const trimSlash = (path) => path.length > 1 ? path.replace(/\/$/, '') : path

const controllerOf = (route) => route.split('#')[0]

// Connects to data-controller='ui--active-link'
// Renders UI::ActiveLink::Component's active state, which the server can't: these links
// are cached fragments, so the markup is shared by every page it was rendered for.
export default class extends Controller {
  static values = { match: String, route: String }

  connect () {
    this.element.classList.toggle('active', this.isActive())
  }

  isActive () {
    return this.matchValue === 'path' ? this.pathMatches() : this.routeMatches()
  }

  // Mirrors current_page?: the query string counts only when the link carries one, so a
  // search link stays active on page 2
  pathMatches () {
    const url = new URL(this.element.href, window.location.href)
    if (url.origin !== window.location.origin) return false
    if (url.search) return url.pathname + url.search === window.location.pathname + window.location.search

    return trimSlash(url.pathname) === trimSlash(window.location.pathname)
  }

  // The page's route comes off the body, since only the server can resolve one
  routeMatches () {
    const pageRoute = document.body.dataset.pageRoute
    if (!this.hasRouteValue || !pageRoute) return false
    if (this.matchValue === 'controller_action') return this.routeValue === pageRoute

    return controllerOf(this.routeValue) === controllerOf(pageRoute)
  }
}
