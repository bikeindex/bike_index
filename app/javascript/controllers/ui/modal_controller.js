import { Controller } from '@hotwired/stimulus'

const SUPPORTS_INVOKERS = 'commandForElement' in window.HTMLButtonElement.prototype

// Connects to data-controller="ui--modal"
// The open state persists to the URL query (?modal_<id>=1) so the modal survives a reload.
// Triggers carry command/commandfor too, so a browser with invoker commands opens the dialog
// itself rather than waiting for this lazy loaded controller, which may not have arrived when
// the click lands. Without them the controller stands in for the browser.
export default class extends Controller {
  static values = { openOnConnect: Boolean }

  connect () {
    if (!SUPPORTS_INVOKERS) {
      this.boundInvoke = this.invokeFallback.bind(this)
      this.invokers.forEach(el => el.addEventListener('click', this.boundInvoke))
    }
    // Already open means an invoker got here before this controller loaded
    if (this.element.open || this.paramInUrl) this.open()
    else if (this.openOnConnectValue) this.showDialog()
  }

  disconnect () {
    if (SUPPORTS_INVOKERS) return

    this.invokers.forEach(el => el.removeEventListener('click', this.boundInvoke))
  }

  // The browser's own show-modal, which fires before it opens the dialog - so this takes
  // the trigger and the bookkeeping and leaves the opening to it
  invoked (event) {
    if (event.command !== 'show-modal') return

    this.markTrigger(event.source)
    this.persist(true)
    this.lockScroll()
  }

  // Stands in for the browser, dispatching on the command it would have run
  invokeFallback (event) {
    const invoker = event.currentTarget
    if (invoker.getAttribute('command') === 'close') return this.close()

    this.markTrigger(invoker)
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
    this.element.close()
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
    trigger.dataset.active = 'true'
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

  // Every button aimed at this dialog, open and close alike
  get invokers () {
    return document.querySelectorAll(`[commandfor="${this.element.id}"]`)
  }
}
