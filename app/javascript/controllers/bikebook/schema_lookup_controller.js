import { Controller } from '@hotwired/stimulus'
import { Turbo } from '@hotwired/turbo-rails'
import { CatalogComboboxSource, catalogAt } from 'bikebook/catalog'
import { localSources } from 'utils/hw_combobox_patch'

// Connects to data-controller='bikebook--schema-lookup'
// /bikebook's search, picking a single model or classification, whose file a pick visits and clearing it leaves. The
// field is a stand-in until the catalog loads, since the combobox must have its source before it connects
export default class extends Controller {
  static targets = ['combobox', 'slot']
  static values = { manifestUrl: String, path: String, clearedUrl: String, display: String, failedText: String }

  async connect () {
    let catalog
    try {
      catalog = await catalogAt(this.manifestUrlValue)
    } catch (error) {
      console.error(error)
      this.slotTarget.querySelector('input').placeholder = this.failedTextValue
      return
    }
    const fragment = this.comboboxTarget.content.cloneNode(true)
    const combobox = fragment.querySelector('.hw-combobox')
    // with an async source the server can only prefill the id, which the gem would display
    if (this.displayValue) combobox.dataset.hwComboboxPrefilledDisplayValue = this.displayValue
    localSources.set(combobox, new CatalogComboboxSource(catalog))
    this.slotTarget.replaceChildren(fragment)
    this.picked = this.slotTarget.querySelector('input[type=hidden]').value
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

  // the gem announces a deletion once it closes, which mustn't visit again
  #visit (picked, url) {
    this.picked = picked
    Turbo.visit(url)
  }
}
