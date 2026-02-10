import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='collapse'
export default class extends Controller {
  static targets = ['content']
  static values = { duration: { type: Number, default: 200 } }

  toggle () {
    collapse('toggle', this.contentTargets, this.durationValue)
  }

  show () {
    collapse('show', this.contentTargets, this.durationValue)
  }

  hide () {
    collapse('hide', this.contentTargets, this.durationValue)
  }
}
