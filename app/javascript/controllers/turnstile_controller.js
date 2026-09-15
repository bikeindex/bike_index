import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='turnstile'
//
// Only the domains the spam complaints come from are asked, so the widget stays hidden
// until the address typed in is one of them. This is which addresses get asked, not
// whether they have to answer - the server checks the token again on submit.
export default class extends Controller {
  static targets = ['widget']
  static values = { domains: Array }

  // Modules load lazily, so this one can arrive after the address was typed - or after
  // form-persist restored it
  connect () {
    this.update()
  }

  // The widget renders only where Turnstile is configured, so the form declares this
  // controller against a target that often isn't there
  update = () => {
    if (!this.hasWidgetTarget) return

    const email = this.element.querySelector('input[type="email"]')?.value?.toLowerCase() ?? ''
    const risky = this.domainsValue.some(domain => email.includes(domain))
    this.widgetTarget.classList.toggle('tw:hidden', !risky)
  }
}
