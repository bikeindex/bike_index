import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='landing-pages--education'
// Steps share one grid cell so the card keeps its height, which is why they're switched by
// visibility here rather than through collapse_utils' display toggle
export default class extends Controller {
  static targets = ['step', 'summary', 'continue', 'done']

  connect () {
    this.index = 0
    this.reached = 0
  }

  check (event) {
    const step = this.stepTargets.find(step => step.contains(event.target))
    step.querySelector('[data-landing-pages--education-target=continue]').disabled = !this.complete(step)
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
    this.element.querySelectorAll('input[type=checkbox]').forEach(box => { box.checked = false })
    this.continueTargets.forEach(button => { button.disabled = true })
    this.reached = 0
    this.show(0)
  }

  // An index past the last step is the done panel, which only a step left unchecked
  // (unchecked on the way back) keeps the rider from
  show (index) {
    const incomplete = this.stepTargets.findIndex(step => !this.complete(step))
    this.index = (index >= this.stepTargets.length && incomplete !== -1) ? incomplete : index
    this.reached = Math.max(this.reached, this.index)

    const current = this.stepTargets[this.index] || this.doneTarget
    ;[...this.stepTargets, this.doneTarget].forEach(panel => panel.classList.toggle('tw:invisible', panel !== current))
    current.querySelector('h3').focus()

    this.summaryTargets.forEach((summary, summaryIndex) => {
      summary.disabled = summaryIndex > this.reached
      summary.toggleAttribute('data-passed', summaryIndex < this.index && this.complete(this.stepTargets[summaryIndex]))
      if (summaryIndex === this.index) {
        summary.setAttribute('aria-current', 'step')
      } else {
        summary.removeAttribute('aria-current')
      }
    })
  }

  complete (step) {
    return [...step.querySelectorAll('input[type=checkbox]')].every(box => box.checked)
  }
}
