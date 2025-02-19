import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='choose-membership--component'
export default class extends Controller {
  connect() {
    // console.log('app/components/choose_membership/component_controller.js - connected to:')
    // console.log(this.element)
  }

  updateIntervalVisibility() {
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
