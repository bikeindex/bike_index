import { Controller } from '@hotwired/stimulus'
import { urlParam, setUrlParam } from 'utils/url_param'

// Connects to data-controller='ebike-rules--classification-toggle'
// Shows the panel its radio picks, and keeps the pick in the URL, as does a link anywhere on the page whose
// data-classification names a panel
export default class extends Controller {
  static targets = ['panel']
  static values = { param: String }

  connect () {
    const classification = urlParam(this.paramValue)
    if (this.#panel(classification)) this.#pick(classification)
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
    document.querySelector(link.hash)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
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
