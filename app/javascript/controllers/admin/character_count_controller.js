import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--character-count'
// Counts a field's characters against max, turning red once over. Not maxlength: the browser
// would block submitting the whole form over one edited field still past it
export default class extends Controller {
  static targets = ['field', 'total']
  static values = { max: Number }

  connect () {
    this.update()
  }

  update () {
    const { value } = this.fieldTarget
    const max = this.maxValue
    this.totalTarget.textContent = `${value.length}/${max}`
    this.totalTarget.classList.toggle('tw:text-red-600', value.length > max)
    this.totalTarget.classList.toggle('tw:text-gray-500', value.length <= max)
  }
}
