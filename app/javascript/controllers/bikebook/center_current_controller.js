import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bikebook--center-current'
// Scrolls this horizontal scroller to center its current item, leaving the page's own scroll where it is
export default class extends Controller {
  connect () {
    const current = this.element.querySelector('[aria-current="true"]')
    if (!current) return

    const [scroller, item] = [this.element, current].map((element) => element.getBoundingClientRect())
    this.element.scrollLeft += item.left + item.width / 2 - (scroller.left + scroller.width / 2)
  }
}
