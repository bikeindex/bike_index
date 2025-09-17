import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='page-section-choose-membership'
export default class extends Controller {
  updateIntervalVisibility () {
    const checkedElement = this.element.querySelector('#intervalSelector input:checked')

    // Get the value of the checked element
    const targetValue = checkedElement.value

    // Hide all elements that don't match the selected value by adding tw-hidden
    this.element.querySelectorAll('.intervalDisplay').forEach(element => {
      if (!element.classList.contains(targetValue)) {
        element.classList.add('tw:hidden!')
      } else {
        element.classList.remove('tw:hidden!')
      }
    })
  }
}
