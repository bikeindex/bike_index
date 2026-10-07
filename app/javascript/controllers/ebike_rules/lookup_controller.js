import { Controller } from '@hotwired/stimulus'
import { CatalogComboboxSource, loadCatalog } from 'bikebook/catalog'
import { localSources } from 'utils/hw_combobox_patch'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ebike-rules--lookup'
// Searches Bike Book's electric models in the browser once its catalog loads, and trades that
// search for the manual entry panel. The bike field is a stand-in until then, and stays one if
// the catalog fails to load, leaving manual entry
export default class extends Controller {
  static targets = ['combobox', 'comboboxSlot', 'manualPanel', 'state']
  static values = { manifestUrl: String, display: String, failedText: String }

  async connect () {
    let catalog
    try {
      catalog = await loadCatalog(this.manifestUrlValue)
    } catch (error) {
      console.error(error)
      this.comboboxSlotTarget.querySelector('input').placeholder = this.failedTextValue
      return this.openManual()
    }
    const fragment = this.comboboxTarget.content.cloneNode(true)
    const combobox = fragment.querySelector('.hw-combobox')
    // with an async source the server can only prefill the id, which the gem would display
    if (this.displayValue) combobox.dataset.hwComboboxPrefilledDisplayValue = this.displayValue
    localSources.set(combobox, new CatalogComboboxSource(catalog))
    this.comboboxSlotTarget.replaceChildren(fragment)
    this.loaded = true
    this.#searchEnabled(!this.#manual)
  }

  openManual () {
    this.manualPanelTarget.disabled = false
    collapse('show', this.manualPanelTarget)
    this.#searchEnabled(false)
  }

  closeManual () {
    this.manualPanelTarget.disabled = true
    collapse('hide', this.manualPanelTarget)
    this.#searchEnabled(true)
    this.comboboxSlotTarget.querySelector('input:not([type=hidden])')?.focus()
  }

  focusState () {
    this.stateTarget.focus()
  }

  get #manual () {
    return !this.manualPanelTarget.disabled
  }

  // The stand-in is never enabled; a disabled hidden field keeps a picked bike out of a manual check
  #searchEnabled (enabled) {
    if (!this.loaded) return

    this.comboboxSlotTarget.querySelectorAll('input').forEach((input) => { input.disabled = !enabled })
  }
}
