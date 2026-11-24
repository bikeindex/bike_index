import { Controller } from '@hotwired/stimulus'
import { Turbo } from '@hotwired/turbo-rails'
import { catalogAt, mountCatalogCombobox } from 'bikebook/catalog'

// Connects to data-controller='bikebook--schema-lookup'
// /bikebook's search, picking a single model or classification, whose file a pick visits and clearing it leaves
export default class extends Controller {
  static targets = ['combobox', 'slot']
  static values = { manifestUrl: String, path: String, clearedUrl: String, display: String, failedText: String }

  async connect () {
    const field = await mountCatalogCombobox(catalogAt(this.manifestUrlValue), this.comboboxTarget, this.slotTarget,
      { display: this.displayValue, failedText: this.failedTextValue })
    this.picked = field?.value
  }

  // Picking nothing - the handle's clear, or Escape once it's closed - leaves the pick. The gem announces the
  // prefilled pick on connecting, which is this page's own
  pick ({ detail: { value } }) {
    if (value !== this.picked) this.#visit(value, value ? `${this.pathValue}/${value}` : this.clearedUrlValue)
  }

  // Deleting the pick's name, which the gem announces only once it closes. Typing over the pick searches
  clear ({ target }) {
    if (this.picked && !target.value) this.#visit('', this.clearedUrlValue)
  }

  #visit (picked, url) {
    this.picked = picked
    Turbo.visit(url)
  }
}
