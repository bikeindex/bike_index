import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='fullscreen-table-overflow'
// Adds 'full-screen-table-overflown' class when a child table is wider than the viewport
export default class extends Controller {
  connect () {
    this.checkOverflow()
    this.resizeHandler = () => this.checkOverflow()
    this.frameRenderHandler = () => this.checkOverflow()
    window.addEventListener('resize', this.resizeHandler)
    document.addEventListener('turbo:frame-render', this.frameRenderHandler)
  }

  disconnect () {
    window.removeEventListener('resize', this.resizeHandler)
    document.removeEventListener('turbo:frame-render', this.frameRenderHandler)
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
