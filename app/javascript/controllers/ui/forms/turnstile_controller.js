import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--turnstile'
//
// Which addresses get asked, not whether they answer - the server re-checks the token.
export default class extends Controller {
  static targets = ['widget']
  static values = { domains: Array, scriptUrl: String, exemptEmails: Array }

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

    const email = this.element.querySelector('input[type="email"]')?.value?.trim()?.toLowerCase() ?? ''
    const risky = this.domainsValue.some(domain => email.includes(domain)) &&
      !this.exemptEmailsValue.includes(email)
    this.widgetTarget.classList.toggle('tw:hidden', !risky)
    if (risky) this.ensureWidget()
  }

  // api.js renders every .cf-turnstile it finds on load, so it ships on the first reveal
  // rather than to everyone who opens the form. A container Turbo swapped in after that
  // load is not one it finds, so a reveal past the first has to render its own
  ensureWidget () {
    if (window.turnstile) return this.renderWidget()
    // In flight from an earlier reveal - its load will find this container itself
    if (document.querySelector(`script[src="${this.scriptUrlValue}"]`)) return

    const script = document.createElement('script')
    script.src = this.scriptUrlValue
    script.defer = true
    document.head.appendChild(script)
  }

  // Rendering a second widget into a container that has one raises. Turbo's cached
  // preview restores an already-rendered container, as does re-revealing
  renderWidget () {
    const container = this.widgetTarget.querySelector('.cf-turnstile')
    if (!container.hasChildNodes()) window.turnstile.render(container)
  }
}
