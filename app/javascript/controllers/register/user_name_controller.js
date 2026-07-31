import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='register--user-name'
//
// The name the ownership takes, asked for unless the registration is going to
// one of the signed-in account's own addresses - which the email field can
// change until it's submitted. Anonymous, the list is empty and it always asks.
export default class extends Controller {
  static targets = ['field']
  static values = { emails: Array }

  update (event) {
    const required = !this.emailsValue.includes(event.target.value.trim().toLowerCase())
    collapse(required ? 'show' : 'hide', this.fieldTarget)
    // Hiding isn't enough - a disabled field neither posts nor holds the submit on required
    this.fieldTarget.querySelector('input').disabled = !required
  }
}
