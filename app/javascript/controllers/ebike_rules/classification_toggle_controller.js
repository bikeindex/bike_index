import { Controller } from '@hotwired/stimulus'
import { urlParam, setUrlParam } from 'utils/url_param'

// Connects to data-controller='ebike-rules--classification-toggle'
// Shows the panel its radio picks, and keeps the pick in the URL. A link elsewhere on the page naming one of its
// panels in data-classification, as the check's alert has, picks it, dispatches revealed and scrolls to the link's anchor
export default class extends Controller {
  static targets = ['panel']
  static values = { param: String }

  connect () {
    const picked = this.#panel(urlParam(this.paramValue))
    if (picked) this.#pick(picked.dataset.classification)
  }

  pick ({ target }) {
    this.#show(target.value)
    setUrlParam(this.paramValue, target.value)
  }

  reveal (event) {
    const link = event.target.closest('a[data-classification]')
    if (!link || !this.#panel(link.dataset.classification) || event.metaKey || event.ctrlKey || event.shiftKey) return

    event.preventDefault()
    this.#pick(link.dataset.classification)
    setUrlParam(this.paramValue, link.dataset.classification)
    this.dispatch('revealed')
    document.getElementById(link.hash.slice(1))?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  #panel (classification) {
    return this.panelTargets.find((panel) => panel.dataset.classification === classification)
  }

  // A state with one classification has no radio to check
  #pick (classification) {
    const radio = this.element.querySelector(`input[value="${classification}"]`)
    if (radio) radio.checked = true
    this.#show(classification)
  }

  #show (classification) {
    this.panelTargets.forEach((panel) => panel.classList.toggle('tw:hidden', panel.dataset.classification !== classification))
  }
}
