import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='shop--index'
export default class extends Controller {
  // Until this loads the link's own href jumps to the same place, and puts it in the URL
  scrollToProducts (event) {
    const target = document.getElementById(event.currentTarget.hash.slice(1))
    if (!target) return

    event.preventDefault()
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    target.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth' })
  }
}
