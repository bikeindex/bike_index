import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='landing-pages--education'
export default class extends Controller {
  static targets = ['step', 'summary', 'continue', 'done']

  connect () {
    this.index = 0
  }

  check (event) {
    const step = this.stepTargets.find(step => step.contains(event.target))
    const boxes = [...step.querySelectorAll('input[type=checkbox]')]
    step.querySelector('[data-landing-pages--education-target=continue]').disabled = !boxes.every(box => box.checked)
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
    this.show(0)
  }

  // An index past the last step is the done panel
  show (index) {
    const previous = this.stepTargets[this.index] || this.doneTarget
    const current = this.stepTargets[index] || this.doneTarget
    this.index = index
    if (previous !== current) {
      collapse('hide', previous, 0)
      collapse('show', current)
    }

    this.summaryTargets.forEach((summary, summaryIndex) => {
      summary.toggleAttribute('data-passed', summaryIndex < index)
      if (summaryIndex === index) {
        summary.setAttribute('aria-current', 'step')
      } else {
        summary.removeAttribute('aria-current')
      }
    })
  }
}
