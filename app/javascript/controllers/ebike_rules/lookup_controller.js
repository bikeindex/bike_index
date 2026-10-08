import { Controller } from '@hotwired/stimulus'
import { Turbo } from '@hotwired/turbo-rails'
import { CatalogComboboxSource, loadCatalog } from 'bikebook/catalog'
import { localSources } from 'utils/hw_combobox_patch'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='ebike-rules--lookup'
// The bike field is a stand-in until the catalog loads, since the combobox must have its source
// before it connects, and stays one if the catalog fails, leaving manual entry. Each state has its own
// page, so the state is the form's path rather than a field, and choosing one goes to its page
export default class extends Controller {
  static targets = ['combobox', 'comboboxSlot', 'manualPanel', 'state', 'throttle']
  static values = { manifestUrl: String, path: String, display: String, failedText: String }

  async connect () {
    this.stateTarget.removeAttribute('name')
    // a state chosen before connecting went unheard
    if (!this.stateTarget.selectedOptions[0]?.defaultSelected) this.chooseState()
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

  // A bike in the form comes along, checked against the new state; without one it's just the state's
  // page, with no errors. Unchoosing one stays put, as /ebike-rules sends a located visitor back
  chooseState () {
    const abbreviation = this.stateTarget.value.toLowerCase()
    if (!abbreviation) {
      this.element.action = this.pathValue
      return
    }
    const fields = new FormData(this.element)
    const query = fields.get('bike') || fields.get('watts') ? `?${new URLSearchParams(fields)}` : ''
    Turbo.visit(`${this.pathValue}/${abbreviation}${query}`)
  }

  // Only Class 2 has a throttle by definition, so a class picked answers the throttle until the rider does
  chooseClass (event) {
    this.throttleTarget.querySelector(`input[value="${event.target.value === '2' ? 1 : 0}"]`).checked = true
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
