import { Controller } from '@hotwired/stimulus'

const SUPPORTS_INVOKERS = 'commandForElement' in window.HTMLButtonElement.prototype

// Connects to data-controller="ui--modal"
// The open state persists to the URL query (?modal_<id>=1) so the modal survives a reload, in a
// history entry of its own so Back closes the modal rather than leaving the page.
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

  // A submit's referer is often where its response redirects, which mustn't reopen the modal
  submitted () {
    this.persist(false)
  }

  // Back and Forward stepping across the entry that opening pushed. Turbo restamps an entry
  // stepped onto without its state, so a reopened one is marked as this modal's again
  popped () {
    if (this.element.open && !this.paramInUrl) {
      this.close()
    } else if (!this.element.open && this.paramInUrl) {
      window.history.replaceState({ modal: this.element.id }, '', window.location.href)
      this.showDialog()
    }
  }

  // Only a press that started on the backdrop closes - a text selection dragged out of the
  // dialog ends in a click on the dialog itself too
  pressed (event) {
    this.pressedBackdrop = event.target === this.element
  }

  backdropClick (event) {
    if (event.target === this.element && this.pressedBackdrop) this.close()
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

  // Opening pushes an entry of its own, so Back closes the modal. The entry under it loses Turbo's
  // state, which Turbo would take a step back onto for a visit, re-rendering the page. Any other
  // close only drops the param - stepping back itself would race whatever the close led to, and
  // abort it - and reopening reuses the entry
  persist (open) {
    if (window.history.state?.modal === this.element.id) {
      window.history.replaceState(window.history.state, '', this.urlWithParam(open))
    } else if (open) {
      const { turbo, ...state } = window.history.state || {}
      window.history.replaceState(state, '', this.urlWithParam(false))
      window.history.pushState({ modal: this.element.id }, '', this.urlWithParam(true))
    } else if (this.paramInUrl) {
      window.history.replaceState(window.history.state, '', this.urlWithParam(false))
    }
  }

  urlWithParam (present) {
    const url = new URL(window.location)
    if (present) url.searchParams.set(this.param, '1')
    else url.searchParams.delete(this.param)
    return url
  }

  // Every button aimed at this dialog, open and close alike
  get invokers () {
    return document.querySelectorAll(`[commandfor="${this.element.id}"]`)
  }
}
