import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--character-count'
// Counts a field's characters against its maxlength, turning red once over. A prefilled field can
// start over, which maxlength doesn't stop
export default class extends Controller {
  static targets = ['field', 'total']

  connect () {
    this.update()
  }

  update () {
    const { value, maxLength } = this.fieldTarget
    this.totalTarget.textContent = `${value.length}/${maxLength}`
    this.totalTarget.classList.toggle('tw:text-red-600', value.length > maxLength)
    this.totalTarget.classList.toggle('tw:text-gray-500', value.length <= maxLength)
  }
}
