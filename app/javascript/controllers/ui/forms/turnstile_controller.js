import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--turnstile'
//
// Which addresses get asked, not whether they answer - the server re-checks the token.
export default class extends Controller {
  static targets = ['widget']
  static values = { domains: Array, scriptUrl: String }

  // Lazily loaded, so the address may already be typed (or form-persist-restored)
  connect () {
    window.addEventListener('form-persist:restored', this.update)
    this.update()
  }

  disconnect () {
    window.removeEventListener('form-persist:restored', this.update)
  }

  // The form declares this controller even where Turnstile is unconfigured, so the
  // widget it toggles often isn't rendered at all
  update = () => {
    if (!this.hasWidgetTarget) return

    const email = this.element.querySelector('input[type="email"]')?.value?.toLowerCase() ?? ''
    const risky = this.domainsValue.some(domain => email.includes(domain))
    this.widgetTarget.classList.toggle('tw:hidden', !risky)
    if (risky) this.loadScript()
  }

  // api.js renders every .cf-turnstile on the page when it loads, so it's fetched on the
  // first reveal rather than shipped to everyone who opens the form
  loadScript () {
    if (this.scriptLoaded) return

    this.scriptLoaded = true
    const script = document.createElement('script')
    script.src = this.scriptUrlValue
    script.defer = true
    document.head.appendChild(script)
  }
}
