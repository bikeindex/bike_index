import { Controller } from '@hotwired/stimulus'
import { Turbo } from '@hotwired/turbo-rails'
import { CatalogComboboxSource, loadCatalog } from 'bikebook/catalog'
import { localSources } from 'utils/hw_combobox_patch'
import { collapse } from 'utils/collapse_utils'

const RESULT_FRAME = 'ebike-rules-check'

// Connects to data-controller='ebike-rules--lookup'
// The bike field is a stand-in until the catalog loads, since the combobox must have its source
// before it connects, and stays one if the catalog fails, leaving manual entry. Each state has its own
// page, so the state is the form's path rather than a field. There's no submit button: a pick or a
// manual change loads its check into the result frame, advancing the URL to the check's own
export default class extends Controller {
  static targets = ['combobox', 'comboboxSlot', 'manualPanel', 'bikeField', 'closeManual', 'state', 'stateNote', 'stateNeeded']
  static values = { manifestUrl: String, path: String, display: String, failedText: String, title: String }

  async connect () {
    this.#stateField.removeAttribute('name')
    this.observers = [this.#watchCleared(this.#stateField, () => this.chooseState())]
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
    const bikeField = this.comboboxSlotTarget.querySelector('input[type=hidden]')
    this.observers.push(this.#watchCleared(bikeField, () => { if (!this.#manual) this.chooseBike() }))
  }

  disconnect () {
    this.observers.forEach((observer) => observer.disconnect())
  }

  // A picked bike is cleared rather than hidden, so it can't come back as the check
  openManual () {
    if (this.#manual) return

    this.comboboxSlotTarget.querySelectorAll('input').forEach((input) => { input.value = '' })
    this.#toggleManual(true)
    this.#leaveCheck(`${this.element.action}?manual=1`)
  }

  closeManual () {
    this.#toggleManual(false)
    this.#leaveCheck(this.element.action)
  }

  // A check in the form comes along to the new state; clearing the state leaves the check waiting for one.
  // The gem restores the field's name on a selection
  chooseState () {
    this.#stateField.removeAttribute('name')
    const abbreviation = this.#stateField.value.toLowerCase()
    this.element.action = abbreviation ? `${this.pathValue}/${abbreviation}` : this.pathValue
    if (abbreviation) {
      this.stateNoteTarget.replaceChildren()
      return this.#visit(this.#checkUrl ?? this.element.action)
    }
    document.title = this.titleValue
    this.#awaitState()
  }

  // The gem leaves the autocompleted part of a pick selected, and the catalog's "(current)" says
  // nothing a picked model needs
  chooseBike ({ detail } = {}) {
    const input = this.comboboxSlotTarget.querySelector('input[role=combobox]')
    if (detail?.value && input) {
      input.value = input.value.replace(/ \(current\)$/, '')
      input.setSelectionRange(input.value.length, input.value.length)
    }
    this.#stateField.value ? this.#visit(this.#checkUrl ?? this.element.action) : this.#awaitState()
  }

  checkManual () {
    const watts = this.element.elements.watts
    if (!watts.checkValidity()) return watts.reportValidity()

    this.#stateField.value ? this.#visit(this.#checkUrl) : this.#awaitState()
  }

  focusState () {
    this.stateTarget.querySelector('input[role=combobox]').focus()
  }

  // A frame load keeps the page's title, which names the state, and shows its verdict wherever it lands
  checkLoaded ({ target }) {
    if (target.id !== RESULT_FRAME) return

    const title = target.querySelector('[data-page-title]')?.dataset.pageTitle
    if (title) document.title = title
    target.querySelector('[role=status]')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }

  get #checkUrl () {
    const fields = new FormData(this.element)
    if (fields.get('vehicle_models') || this.#manual) return `${this.element.action}?${new URLSearchParams(fields)}`
  }

  // The gem announces a prefilled selection on connecting, which mustn't reload the check it's showing.
  // A state's or the form's hash doesn't make it another check
  #visit (url) {
    if (url !== window.location.href.split('#')[0]) Turbo.visit(url, { frame: RESULT_FRAME, action: 'advance' })
  }

  // Without a state there's nothing to check a bike against, so it waits in the URL for one
  #awaitState () {
    const url = this.#checkUrl
    this.#leaveCheck(url ?? this.element.action)
    if (!url) return this.stateNoteTarget.replaceChildren()

    this.stateNoteTarget.replaceChildren(this.stateNeededTarget.content.cloneNode(true))
    this.focusState()
  }

  #leaveCheck (url) {
    document.getElementById(RESULT_FRAME).replaceChildren()
    window.history.replaceState(window.history.state, '', url)
  }

  #toggleManual (manual) {
    this.manualPanelTarget.disabled = !manual
    collapse(manual ? 'show' : 'hide', [this.manualPanelTarget, this.closeManualTarget])
    collapse(manual ? 'hide' : 'show', this.bikeFieldTarget)
    this.#searchEnabled(!manual)
  }

  // A combobox handle's clear empties the field without a selection event, so the field itself is watched
  #watchCleared (field, onCleared) {
    const observer = new window.MutationObserver(() => { if (!field.value) onCleared() })
    observer.observe(field, { attributeFilter: ['value'] })
    return observer
  }

  get #stateField () {
    return this.stateTarget.querySelector('input[type=hidden]')
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
