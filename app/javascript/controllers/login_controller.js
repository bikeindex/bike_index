import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='login'
// Identifier-first sign in: collect the email, ask the server which credential the
// email's organization requires, then reveal the matching step. Progressive
// enhancement — without JS the password step is already visible and the form works.
// The password field stays in the DOM the whole time (only its container is toggled)
// so password managers can still associate username + password for autofill.
export default class extends Controller {
  static targets = ['form', 'email', 'continueStep', 'passwordStep', 'passwordInput',
    'magicLinkStep', 'magicLinkButton', 'changeEmail', 'altMethods']

  static values = { lookupUrl: String, magicLinkUrl: String }

  connect () {
    this.defaultAction = this.formTarget.getAttribute('action')
    // Alternate sign-in methods (the standalone magic-link link, the "or" divider) are
    // no-JS fallbacks — hide them so nothing surfaces until the email check resolves.
    this.altMethodsTargets.forEach((element) => this.toggle(element, false))
    this.reset()
    // A pre-filled email (e.g. re-rendered after a failed password attempt) skips
    // straight to its step so the user isn't asked to click Continue again.
    if (this.emailTarget.value.trim() !== '') this.advance()
  }

  continue (event) {
    event.preventDefault()
    if (this.emailTarget.reportValidity()) this.advance()
  }

  async advance () {
    const email = this.emailTarget.value.trim()
    if (email === '') return
    let method = 'password' // safe universal fallback if the lookup fails
    try {
      const response = await fetch(this.lookupUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ email })
      })
      if (response.ok) method = (await response.json()).method
    } catch (_error) {}
    this.reveal(method)
  }

  reveal (method) {
    const magic = method === 'magic_link'
    this.toggle(this.continueStepTarget, false)
    this.toggle(this.changeEmailTarget, true)
    this.toggle(this.passwordStepTarget, !magic)
    this.toggle(this.magicLinkStepTarget, magic)
    if (magic) this.magicLinkButtonTarget.focus()
    else this.passwordInputTarget.focus()
  }

  changeEmail (event) {
    event.preventDefault()
    this.formTarget.setAttribute('action', this.defaultAction)
    this.reset()
    this.emailTarget.focus()
  }

  // Magic-link submit posts the whole session form to create_magic_link, which reads a
  // top-level email param, so mirror the email there before submitting.
  sendMagicLink (event) {
    event.preventDefault()
    const form = this.formTarget
    form.setAttribute('action', this.magicLinkUrlValue)
    let hidden = form.querySelector('input[name="email"]')
    if (hidden == null) {
      hidden = document.createElement('input')
      hidden.type = 'hidden'
      hidden.name = 'email'
      form.appendChild(hidden)
    }
    hidden.value = this.emailTarget.value.trim()
    form.submit()
  }

  reset () {
    this.toggle(this.continueStepTarget, true)
    this.toggle(this.changeEmailTarget, false)
    this.toggle(this.passwordStepTarget, false)
    this.toggle(this.magicLinkStepTarget, false)
  }

  toggle (element, visible) {
    element.classList.toggle('tw:hidden', !visible)
  }

  get csrfToken () {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
