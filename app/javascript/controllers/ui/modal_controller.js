import { Controller } from '@hotwired/stimulus'

const supportsInvokers = () => 'commandForElement' in window.HTMLButtonElement.prototype

// Connects to data-controller="ui--modal"
// The open state persists to the URL query (?modal_<id>=1) so the modal survives a reload.
// Triggers carry command/commandfor as well, so a browser with invoker commands opens the
// dialog itself rather than waiting for this controller to load - which it may not have
// when the click lands. There the click listener stands down and #invoked keeps the
// bookkeeping; without invokers the listener opens the dialog as it always did.
export default class extends Controller {
  static values = { openOnConnect: Boolean }

  connect () {
    this.boundOpen = this.openFromTrigger.bind(this)
    this.boundClose = this.close.bind(this)
    // Without invoker commands this controller stands in for the browser
    if (!supportsInvokers()) {
      this.triggers.forEach(el => el.addEventListener('click', this.boundOpen))
      this.closers.forEach(el => el.addEventListener('click', this.boundClose))
    }
    // Already open means an invoker got here before this controller loaded
    if (this.element.open || this.paramInUrl) this.open()
    else if (this.openOnConnectValue) this.showDialog()
  }

  disconnect () {
    this.triggers.forEach(el => el.removeEventListener('click', this.boundOpen))
    this.closers.forEach(el => el.removeEventListener('click', this.boundClose))
  }

  // The browser's own show-modal, which fires before it opens the dialog - so this takes
  // the trigger and the bookkeeping and leaves the opening to it
  invoked (event) {
    if (event.command !== 'show-modal') return

    this.markTrigger(event.source)
    this.persist(true)
    this.lockScroll()
  }

  openFromTrigger (event) {
    this.markTrigger(event.currentTarget)
    this.open()
  }

  open () {
    this.showDialog()
    this.persist(true)
  }

  // A modal the server rendered open (openOnConnect) skips the param: whether it
  // comes back after a reload is the server's call, not the URL's
  showDialog () {
    if (!this.element.open) this.element.showModal()
    this.lockScroll()
  }

  close () {
    if (this.element.open) this.element.close()
  }

  // Every close ends here - the close command, Escape and #close all fire the dialog's
  // own `close`, so the cleanup runs once wherever it started
  closed () {
    document.body.classList.remove('tw:overflow-hidden')
    if (this.trigger) {
      delete this.trigger.dataset.active
      this.trigger = null
    }
    this.persist(false)
  }

  backdropClick (event) {
    if (event.target === this.element) {
      this.close()
    }
  }

  // data-active, not an `active` class: that's what the is-active variant matches
  markTrigger (trigger) {
    this.trigger = trigger
    if (trigger) trigger.dataset.active = 'true'
  }

  lockScroll () {
    document.body.classList.add('tw:overflow-hidden')
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

  get closers () {
    return this.element.querySelectorAll('[command="close"]')
  }
}
