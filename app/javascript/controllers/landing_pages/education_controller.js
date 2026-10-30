import { Controller } from '@hotwired/stimulus'
import { urlParam, setUrlParam } from 'utils/url_param'

// Connects to data-controller='landing-pages--education'
// Steps are switched by visibility rather than collapse_utils' display toggle, which would
// collapse the grid cell they share. Each step's own register--acknowledgment gates its Continue
export default class extends Controller {
  static targets = ['step', 'summary', 'done']

  connect () {
    this.index = 0
    if (urlParam('education_step')) this.sync()
  }

  // Every tab is on the step in the URL - 1-based, one past the last step being the done panel
  sync () {
    const step = Number(urlParam('education_step'))
    this.show((Number.isInteger(step) && step >= 1 ? step : 1) - 1, { focus: false })
  }

  // The second click of a double-click would land on whatever the first one's step change put
  // under it - the next step's Back link, or one of its rules
  guard (event) {
    if (event.detail < 2) return

    event.preventDefault()
    event.stopImmediatePropagation()
  }

  next () {
    this.show(this.index + 1)
  }

  back () {
    this.show(this.index - 1)
  }

  go ({ params }) {
    this.show(params.index)
  }

  restart () {
    this.element.querySelectorAll('input[type=checkbox]').forEach(box => {
      box.checked = false
      box.dispatchEvent(new Event('change'))
    })
    this.show(0)
  }

  // An index past the last step is the done panel - reachable with earlier steps unchecked,
  // since this is a demo rather than a registration
  show (index, { focus = true } = {}) {
    this.index = Math.min(index, this.stepTargets.length)

    const current = this.stepTargets[this.index] || this.doneTarget
    ;[...this.stepTargets, this.doneTarget].forEach(panel => panel.classList.toggle('tw:invisible', panel !== current))
    if (focus) current.focus()
    setUrlParam('education_step', this.index + 1)

    this.summaryTargets.forEach((summary, summaryIndex) => {
      summary.toggleAttribute('data-passed', summaryIndex !== this.index && this.complete(this.stepTargets[summaryIndex]))
      summary.ariaCurrent = summaryIndex === this.index ? 'step' : null
    })
  }

  complete (step) {
    return [...step.querySelectorAll('input[type=checkbox]')].every(box => box.checked)
  }
}
