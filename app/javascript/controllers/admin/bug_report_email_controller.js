import { Controller } from '@hotwired/stimulus'
import { collapse, collapseField } from 'utils/collapse_utils'

// Connects to data-controller='admin--bug-report-email'
// Opens the bug reports table's email card, ready to type into, and shows its banned alert
// while a checked row's sender is email banned
export default class extends Controller {
  static targets = ['panel', 'message', 'bannedAlert', 'trigger']

  connect () {
    this.sync()
  }

  toggle () {
    this.setOpen(this.triggerTarget.getAttribute('aria-expanded') !== 'true')
  }

  show () {
    this.setOpen(true)
  }

  setOpen (open) {
    // Disabled while closed, so the required message doesn't block the table form's other submits
    collapseField(this.panelTarget, open)
    this.triggerTarget.setAttribute('aria-expanded', String(open))
    this.triggerTarget.dataset.active = String(open)
    if (open) this.messageTarget.focus()
  }

  sync () {
    const banned = !!this.element.querySelector('input[data-email-banned]:checked')
    collapse(banned ? 'show' : 'hide', this.bannedAlertTarget)
  }
}
