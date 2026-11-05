import { Controller } from '@hotwired/stimulus'
import { urlParam, setUrlParam } from 'utils/url_param'

// Connects to data-controller='ebike-rules--classification-toggle'
// Shows the panel its radio picks, and keeps the pick in the URL
export default class extends Controller {
  static targets = ['panel']
  static values = { param: String }

  connect () {
    const picked = this.panelTargets.find((panel) => panel.dataset.classification === urlParam(this.paramValue))
    if (!picked) return

    this.element.querySelector(`input[value="${picked.dataset.classification}"]`).checked = true
    this.#show(picked.dataset.classification)
  }

  pick ({ target }) {
    this.#show(target.value)
    setUrlParam(this.paramValue, target.value)
  }

  #show (classification) {
    this.panelTargets.forEach((panel) => panel.classList.toggle('tw:hidden', panel.dataset.classification !== classification))
  }
}
