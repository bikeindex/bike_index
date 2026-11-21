import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='scroll-to-hash', on a link to an anchor on its own page
// Until this loads the link's own href jumps to the same place, and puts it in the URL
export default class extends Controller {
  scroll (event) {
    const target = document.getElementById(this.element.hash.slice(1))
    if (!target || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return

    event.preventDefault()
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    target.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth' })
  }
}
