import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--character-count'
// Counts a field's characters against max, turning red once over. Not maxlength: the browser
// would block submitting the whole form over one edited field still past it.
// The red is important, so it beats the total's own color, a utility or legacy .text-info alike
export default class extends Controller {
  static targets = ['field', 'total']
  static values = { max: Number }

  connect () {
    this.update()
  }

  update () {
    const { length } = this.fieldTarget.value
    this.totalTarget.textContent = `${length}/${this.maxValue}`
    this.totalTarget.classList.toggle('tw:text-red-600!', length > this.maxValue)
  }
}
