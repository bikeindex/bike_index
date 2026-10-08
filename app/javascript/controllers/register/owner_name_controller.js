import { Controller } from '@hotwired/stimulus'
import { collapseField } from 'utils/collapse_utils'

// Connects to data-controller='register--owner-name'
//
// On the single page the owner's email is typed into the same form, so their name is
// asked for only while that email isn't one of the registrant's own.
export default class extends Controller {
  static values = { ownEmails: Array }

  // Modules load lazily, so this one can arrive after form-persist has restored the email
  connect () {
    this.apply(0)
  }

  update () {
    this.apply()
  }

  apply (duration) {
    const email = this.element.closest('form')?.querySelector('input[name="b_param[owner_email]"]')?.value || ''
    collapseField(this.element, !this.ownEmailsValue.includes(email.trim().toLowerCase()), duration)
  }
}
