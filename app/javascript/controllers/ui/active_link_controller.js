import { Controller } from '@hotwired/stimulus'

// Rails' current_page? ignores a trailing slash on either side
const trimSlash = (path) => path.length > 1 ? path.replace(/\/$/, '') : path

const segmentsOf = (path) => trimSlash(path).split('/')

// '*' stands for one segment and a trailing '**' for the rest, so /bikes/*/edit can't span a
// slash and /o/x/exports/** covers the index it's rooted at as well as everything below it
const matchesPath = (pattern, path) => {
  const patternSegments = segmentsOf(pattern)
  const pathSegments = segmentsOf(path)
  const stopped = patternSegments.findIndex((segment, index) =>
    segment === '**' || (segment !== '*' && segment !== pathSegments[index]))

  if (stopped === -1) return patternSegments.length === pathSegments.length

  return patternSegments[stopped] === '**'
}

// Connects to data-controller='ui--active-link'
// Renders UI::ActiveLink::Component's aria-current, which the server can't: these links are
// cached fragments, so the markup is shared by every page it was rendered for.
export default class extends Controller {
  static values = { matchPaths: String, matchParams: Object }

  connect () {
    if (!this.isActive()) return this.element.removeAttribute('aria-current')

    this.element.setAttribute('aria-current', this.ariaCurrent())
    // Announced for a menu that has to react to which of its links is the current one --
    // a collapsed section opening around it. Fired from connect, which for a link runs
    // after its ancestors', so a listener up the tree is already wired
    this.dispatch('current')
  }

  isActive () {
    return this.sameOrigin() && this.coversPath() && this.paramsMatch()
  }

  // Off-site, the page can never be one the link covers
  sameOrigin () {
    return this.element.origin === window.location.origin
  }

  // Space-separated, since a path can't carry a space and JSON would escape every quote
  get patterns () {
    return this.matchPathsValue.split(' ')
  }

  coversPath () {
    return this.patterns.some((pattern) => matchesPath(pattern, window.location.pathname))
  }

  // A link naming no params ignores the query string, and one naming some ignores the rest.
  // '' is UI::ActiveLink::Component::BLANK, which a URL writes as an empty param or none.
  paramsMatch () {
    const current = new URLSearchParams(window.location.search)

    return Object.entries(this.matchParamsValue)
      .every(([param, values]) => values.includes(current.get(param) ?? ''))
  }

  // "page" is reserved for the link whose own path is the current one -- a pattern can name a
  // page the link doesn't point at, so matching one isn't enough. A wildcard, or params the
  // link stands for rather than points at, means the page sits inside what it covers --
  // aria-current's "true", so a reader isn't told a link elsewhere is where they already are
  ariaCurrent () {
    const path = trimSlash(window.location.pathname)
    const isPage = !this.hasMatchParamsValue && this.patterns.includes(path) &&
      trimSlash(this.element.pathname) === path

    return isPage ? 'page' : 'true'
  }
}
