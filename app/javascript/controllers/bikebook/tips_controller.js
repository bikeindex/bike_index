import { Controller } from '@hotwired/stimulus'
import { storage } from 'utils/storage'

const KEY = 'bikebook_tips_dismissed'

// Connects to data-controller='bikebook--tips'
// The empty page's tips, or once they're dismissed the prompt that brings them back. Each swap moves focus to
// what replaced the button pressed
export default class extends Controller {
  static targets = ['tips', 'prompt', 'restore']

  // a classification's card, shown alone, has neither
  connect () {
    if (this.hasTipsTarget) this.#show(!this.#dismissed)
  }

  dismiss () {
    storage.setItem(KEY, '1')
    this.#show(false)
    this.restoreTarget.focus()
  }

  restore () {
    storage.removeItem(KEY)
    this.#show(true)
    this.tipsTarget.firstElementChild.focus()
  }

  // for the search, which opens its own list, and its filter panel
  browse () {
    this.dispatch('browse')
  }

  filters () {
    this.dispatch('filters')
  }

  #show (tips) {
    this.tipsTarget.hidden = !tips
    this.promptTarget.hidden = tips
  }

  get #dismissed () {
    return storage.getItem(KEY) === '1'
  }
}
