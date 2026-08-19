import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--embed-iframe'
// The embedded registration form is served from this host, so the frame can be sized to
// what it actually renders rather than to a guessed min-height that clips the form once
// it grows. Framed on someone else's page it's cross-origin and contentDocument throws -
// the stylesheet's min-height stands in.
export default class extends Controller {
  connect () {
    this.fit = this.fit.bind(this)
    this.element.addEventListener('load', this.fit)
    this.fit()
  }

  disconnect () {
    this.element.removeEventListener('load', this.fit)
    this.observer?.disconnect()
  }

  fit () {
    const body = this.contentBody
    if (!body) return

    // body rather than documentElement, which can't report less than the height we just
    // gave the frame - so a form that collapses would never shrink it back
    this.observer?.disconnect()
    this.observer = new ResizeObserver(() => this.setHeight(body))
    this.observer.observe(body)
    this.setHeight(body)
  }

  setHeight (body) {
    this.element.style.height = `${body.scrollHeight}px`
  }

  get contentBody () {
    try {
      return this.element.contentDocument?.body
    } catch {
      return null
    }
  }
}
