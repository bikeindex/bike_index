import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--range'
// Shows the slider's value as it moves
export default class extends Controller {
  static targets = ['output']

  update ({ target }) {
    this.outputTarget.value = target.value
  }
}
