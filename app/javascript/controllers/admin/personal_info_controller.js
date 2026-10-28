import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--personal-info'
// Flags a recovery story that still holds a phone number, email or street address, and asks
// before "Display selected" publishes one. patterns: {name: {label, source}}, from the component
export default class extends Controller {
  static targets = ['field', 'warning']
  static values = { patterns: Object }

  connect () {
    this.matchers = Object.values(this.patternsValue).map(({ label, source }) => ({ label, regexp: new RegExp(source, 'i') }))
    this.fieldTargets.forEach(field => this.flag(field))
  }

  check ({ target }) {
    if (this.fieldTargets.includes(target)) this.flag(target)
  }

  confirmDisplay (event) {
    if (event.submitter?.value !== 'display') return
    const flagged = this.fieldTargets.filter(field => field.closest('tr').querySelector('input[type=checkbox]:checked') && this.labels(field).length)
    if (flagged.length === 0) return
    const message = `${flagged.length} selected ${flagged.length === 1 ? 'story still contains' : 'stories still contain'} a phone number, email or street address. Display anyway?`
    if (!confirm(message)) event.preventDefault()
  }

  flag (field) {
    const labels = this.labels(field)
    field.classList.toggle('tw:ring-2', labels.length > 0)
    field.classList.toggle('tw:ring-amber-400', labels.length > 0)
    this.warningTargets.find(warning => warning.closest('td') === field.closest('td')).textContent =
      labels.length ? `Contains ${labels.join(', ')}` : ''
  }

  labels (field) {
    return this.matchers.filter(({ regexp }) => regexp.test(field.value)).map(({ label }) => label)
  }
}
