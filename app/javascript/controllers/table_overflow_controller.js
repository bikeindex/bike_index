import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='table-overflow'
// Adds 'table-overflown' class when a child table is wider than the viewport
export default class extends Controller {
  connect () {
    this.checkOverflow = this.checkOverflow.bind(this)
    this.checkOverflow()
    window.addEventListener('resize', this.checkOverflow)
    document.addEventListener('turbo:frame-render', this.checkOverflow)
  }

  disconnect () {
    window.removeEventListener('resize', this.checkOverflow)
    document.removeEventListener('turbo:frame-render', this.checkOverflow)
  }

  checkOverflow () {
    const pageWidth = window.innerWidth
    const table = this.element.querySelector('table')
    if (table && table.offsetWidth > pageWidth) {
      this.element.classList.add('table-overflown')
      this.element.setAttribute('tabindex', '0')
    } else {
      this.element.classList.remove('table-overflown')
      this.element.removeAttribute('tabindex')
    }
  }
}
