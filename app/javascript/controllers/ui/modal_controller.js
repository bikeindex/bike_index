import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="ui--modal"
export default class extends Controller {
  connect () {
    this.boundOpen = this.openFromTrigger.bind(this)
    this.triggers.forEach(el => el.addEventListener('click', this.boundOpen))
  }

  disconnect () {
    this.triggers.forEach(el => el.removeEventListener('click', this.boundOpen))
  }

  openFromTrigger (event) {
    this.trigger = event.currentTarget
    this.trigger.classList.add('active')
    this.element.showModal()
    document.body.classList.add('tw:overflow-hidden')
  }

  close () {
    this.element.close()
    document.body.classList.remove('tw:overflow-hidden')
    if (this.trigger) {
      this.trigger.classList.remove('active')
      this.trigger = null
    }
  }

  backdropClick (event) {
    if (event.target === this.element) {
      this.close()
    }
  }

  handleKeydown (event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  get triggers () {
    return document.querySelectorAll(`[data-open-modal="${this.element.id}"]`)
  }
}
