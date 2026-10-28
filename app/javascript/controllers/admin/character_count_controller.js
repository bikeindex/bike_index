import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='admin--character-count'
// Counts a field's characters against its max, turning red once over. A prefilled field can start
// over, which the maxlength attribute doesn't stop
export default class extends Controller {
  static targets = ['field', 'total']
  static values = { max: Number }

  connect () {
    this.update()
  }

  update () {
    const length = this.fieldTarget.value.length
    this.totalTarget.textContent = `${length}/${this.maxValue}`
    this.totalTarget.classList.toggle('tw:text-red-600', length > this.maxValue)
    this.totalTarget.classList.toggle('tw:text-gray-500', length <= this.maxValue)
  }
}
