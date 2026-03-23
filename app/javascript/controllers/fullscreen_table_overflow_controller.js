import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='fullscreen-table-overflow'
// Adds 'full-screen-table-overflown' class when a child table is wider than the viewport
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
      this.element.classList.add('full-screen-table-overflown')
    } else {
      this.element.classList.remove('full-screen-table-overflown')
    }
  }
}
