import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='alert'
export default class extends Controller {
close () {
this.element.classList.add('tw:opacity-0', 'tw:scale-95')
// Wait for transition to complete before hiding completely
setTimeout(() => {
this.element.classList.add('tw:hidden')
}, 300)
  }
}
