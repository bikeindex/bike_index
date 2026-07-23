import { Controller } from '@hotwired/stimulus'

// Connects to data-controller="ui--modal"
// The open state persists to the URL query (?modal_<id>=1) so the modal survives a reload.
export default class extends Controller {
  connect () {
    this.boundOpen = this.openFromTrigger.bind(this)
    this.triggers.forEach(el => el.addEventListener('click', this.boundOpen))
    if (this.paramInUrl) this.open()
  }

  disconnect () {
    this.triggers.forEach(el => el.removeEventListener('click', this.boundOpen))
  }

  openFromTrigger (event) {
    this.trigger = event.currentTarget
    this.trigger.classList.add('active')
    this.open()
  }

  open () {
    this.element.showModal()
    document.body.classList.add('tw:overflow-hidden')
    this.persist(true)
  }

  close () {
    this.element.close()
    document.body.classList.remove('tw:overflow-hidden')
    if (this.trigger) {
      this.trigger.classList.remove('active')
      this.trigger = null
    }
    this.persist(false)
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

  get param () {
    return `modal_${this.element.id}`
  }

  get paramInUrl () {
    return new URLSearchParams(window.location.search).has(this.param)
  }

  persist (open) {
    const url = new URL(window.location)
    if (open) {
      url.searchParams.set(this.param, '1')
    } else {
      url.searchParams.delete(this.param)
    }
    // replaceState (not pushState) so opening doesn't stack history entries.
    window.history.replaceState(window.history.state, '', url)
  }

  get triggers () {
    return document.querySelectorAll(`[data-open-modal="${this.element.id}"]`)
  }
}
