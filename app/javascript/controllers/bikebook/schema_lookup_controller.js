import { Controller } from '@hotwired/stimulus'
import { Turbo } from '@hotwired/turbo-rails'
import { CatalogComboboxSource, loadCatalog } from 'bikebook/catalog'
import { localSources } from 'utils/hw_combobox_patch'

/* global AbortController */

// Connects to data-controller='bikebook--schema-lookup'
// /bikebook's search, picking a single model or classification, whose file a pick visits and clearing it leaves. The
// field is a stand-in until the catalog loads, since the combobox must have its source before it connects
export default class extends Controller {
  static targets = ['combobox', 'slot']
  static values = { manifestUrl: String, path: String, clearedUrl: String, display: String, failedText: String }

  async connect () {
    this.loading = new AbortController()
    let catalog
    try {
      catalog = await loadCatalog(this.manifestUrlValue, [], {}, {}, { signal: this.loading.signal })
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

  disconnect () {
    this.loading.abort()
  }

  // The gem announces the prefilled pick on connecting, which is this page's own
  pick ({ detail: { value } }) {
    if (value && value !== this.picked) Turbo.visit(`${this.pathValue}/${value}`)
  }

  // The handle's clear, which no selection event announces. Typing over the pick empties the field too, but searches
  clear ({ target }) {
    if (this.picked && target.closest('.hw-combobox__handle')) Turbo.visit(this.clearedUrlValue)
  }
}
