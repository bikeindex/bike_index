import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='bikebook--geometry-overlay'
// A legend button fades the other frames and draws its own over them, until it's pressed again
export default class extends Controller {
  static targets = ['frame', 'button', 'top']

  toggle ({ currentTarget }) {
    const pressed = currentTarget.getAttribute('aria-pressed') !== 'true'
    const index = this.buttonTargets.indexOf(currentTarget)
    this.buttonTargets.forEach((button) => button.setAttribute('aria-pressed', pressed && button === currentTarget))
    this.frameTargets.forEach((frame, each) => pressed && each !== index ? frame.setAttribute('opacity', '0.2') : frame.removeAttribute('opacity'))
    pressed ? this.topTarget.setAttribute('href', `#${this.frameTargets[index].id}`) : this.topTarget.removeAttribute('href')
  }
}
