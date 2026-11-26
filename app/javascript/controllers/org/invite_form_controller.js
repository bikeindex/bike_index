import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// No brackets, commas or a trailing dot, so a pasted "Name <a@b.co>" or "a@b.co." is flagged
const EMAIL_PATTERN = /^[^@\s<>(),;]+@[^@\s<>(),;]+\.[^@\s.<>(),;]+$/

// Connects to data-controller='org--invite-form'
export default class extends Controller {
  static targets = ['emails', 'count', 'invalid', 'limit', 'submit']
  static values = {
    emailsCount: Object, // plural templates, with %{count}
    sendLabel: String,
    sendManyLabel: String, // with %{count}
    notValid: String, // with %{emails}
    left: Object, // plural templates, with %{count}
    remaining: Number // present only when invitations are restricted
  }

  connect () {
    this.check()
  }

  check () {
    // Keyed by lowercase, since the server treats Dave@ and dave@ as one address
    const emails = [...new Map(this.emailsTarget.value.split(/[\s,;]+/).filter(Boolean).map((email) => [email.toLowerCase(), email])).values()]
    const invalid = emails.filter((email) => !EMAIL_PATTERN.test(email))
    const count = emails.length - invalid.length
    const over = this.hasRemainingValue && count > this.remainingValue

    this.countTarget.textContent = count === 0 ? '' : this.pluralize(this.emailsCountValue, count)
    this.countTarget.classList.toggle('tw:text-red-600', over)
    this.emailsTarget.classList.toggle('tw:border-red-600!', invalid.length > 0 || over)
    this.invalidTarget.textContent = invalid.length ? this.notValidValue.replace('%{emails}', invalid.join(', ')) : ''
    this.limitTarget.textContent = over ? this.pluralize(this.leftValue, this.remainingValue) : ''
    collapse(invalid.length > 0 ? 'show' : 'hide', this.invalidTarget)
    collapse(over ? 'show' : 'hide', this.limitTarget)
    this.submitTarget.disabled = count === 0 || invalid.length > 0 || over
    this.submitTarget.textContent = count > 1 ? this.sendManyLabelValue.replace('%{count}', count) : this.sendLabelValue
  }

  pluralize (templates, count) {
    return (count === 1 ? templates.one : templates.other).replace('%{count}', count)
  }
}
