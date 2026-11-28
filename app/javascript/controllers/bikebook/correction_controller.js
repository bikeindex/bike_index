import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'
import { storage } from 'utils/storage'

const KEY = 'bikebook_correction_dismissed'

// Connects to data-controller='bikebook--correction'
// The floating button until it's dismissed, which leaves the link at the bottom of the page. Signing in and sending
// both take the page as it is then, which bikebook--page keeps in the URL
export default class extends Controller {
  static targets = ['floating', 'link', 'pageUrl']
  static values = { modalParam: String }

  connect () {
    if (storage.getItem(KEY) !== '1') collapse('show', this.floatingTarget)
  }

  dismiss () {
    storage.setItem(KEY, '1')
    collapse('hide', this.floatingTarget)
    this.linkTarget.focus()
  }

  signIn (event) {
    const href = new URL(event.currentTarget.href)
    href.searchParams.set('return_to', this.#pageUrl(true))
    event.currentTarget.href = href
  }

  submit () {
    this.pageUrlTarget.value = this.#pageUrl(false)
  }

  #pageUrl (modalOpen) {
    const url = new URL(window.location.href)
    modalOpen ? url.searchParams.set(this.modalParamValue, '1') : url.searchParams.delete(this.modalParamValue)
    return modalOpen ? url.pathname + url.search : url.href
  }
}
