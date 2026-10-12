import { Controller } from '@hotwired/stimulus'
import { Turbo } from '@hotwired/turbo-rails'
import { CatalogComboboxSource, loadCatalog } from 'bikebook/catalog'
import { localSources } from 'utils/hw_combobox_patch'
import { replaceUrl } from 'bikebook/replace_url'

const RESULT_FRAME = 'ebike-rules-check'
const CLASSES_FRAME = 'ebike-rules-classes'
const DETAILS = ['manual', 'top_speed', 'throttle', 'watts']

// Connects to data-controller='ebike-rules--lookup'
// The bike field is a stand-in until the catalog loads, since the combobox must have its source
// before it connects, and stays one if the catalog fails, leaving the details. Each state has its own
// page, so the state is the form's path rather than a field. There's no submit button: a pick or a
// change to the details loads its check into the result frame, advancing the URL to the check's own.
// The form's data-details says which the check is of: a picked "model", whose details its check copies
// into the panel; "custom" details changed from the model's; or "manual" details with no model
export default class extends Controller {
  static targets = ['combobox', 'comboboxSlot', 'state', 'stateNote', 'stateNeeded', 'manual', 'legend']
  static values = { manifestUrl: String, path: String, display: String, failedText: String, title: String, legend: String, modelLegend: String }

  async connect () {
    this.lastUrl = window.location.href.split('#')[0]
    this.classesPath = window.location.pathname
    this.observers = [this.#watchCleared(this.#stateField, () => this.chooseState())]
    let catalog
    try {
      catalog = await loadCatalog(this.manifestUrlValue)
    } catch (error) {
      console.error(error)
      this.comboboxSlotTarget.querySelector('input').placeholder = this.failedTextValue
      return
    }
    const fragment = this.comboboxTarget.content.cloneNode(true)
    const combobox = fragment.querySelector('.hw-combobox')
    // with an async source the server can only prefill the id, which the gem would display
    if (this.displayValue) combobox.dataset.hwComboboxPrefilledDisplayValue = this.displayValue
    localSources.set(combobox, new CatalogComboboxSource(catalog))
    this.comboboxSlotTarget.replaceChildren(fragment)
    const bikeField = this.comboboxSlotTarget.querySelector('input[type=hidden]')
    this.model = bikeField.value
    this.observers.push(this.#watchCleared(bikeField, () => { if (this.model) this.#clearModel() }))
  }

  disconnect () {
    this.observers.forEach((observer) => observer.disconnect())
  }

  // A check in the form comes along to the new state, whose page it loads even without one for its title;
  // clearing the state leaves the check waiting for one
  chooseState () {
    const abbreviation = this.#stateField.value.toLowerCase()
    this.element.action = abbreviation ? `${this.pathValue}/${abbreviation}` : this.pathValue
    this.#loadClasses()
    if (!abbreviation) {
      document.title = this.titleValue
      return this.#awaitState()
    }
    this.stateNoteTarget.replaceChildren()
    this.#visit(this.#checkUrl ?? this.element.action)
  }

  // The gem leaves the autocompleted part of a pick selected, and the catalog's "(current)" says
  // nothing a picked model needs. It also announces the prefilled model on connecting, which keeps the
  // page's custom details
  chooseBike ({ detail } = {}) {
    const input = this.comboboxSlotTarget.querySelector('input[role=combobox]')
    if (detail?.value && input) {
      input.value = input.value.replace(/ \(current\)$/, '')
      input.setSelectionRange(input.value.length, input.value.length)
    }
    if (detail?.value && detail.value !== this.model) {
      this.model = detail.value
      this.#setMode('model')
      // the pick's name, without the catalog's years
      this.legendTarget.textContent = this.modelLegendValue.replace('%{model}', input.value.replace(/ \([^)]*\)$/, ''))
    }
    this.#check()
  }

  // Changing a picked model's details checks them instead
  checkDetails () {
    const watts = this.element.elements.watts
    if (!watts.checkValidity()) return watts.reportValidity()

    if (this.#mode === 'model') this.#setMode('custom')
    this.#check()
  }

  focusState () {
    this.stateTarget.querySelector('input[role=combobox]').focus()
  }

  // A frame load keeps the page's title, which names the state, and shows its verdict wherever it lands
  checkLoaded ({ target }) {
    if (target.id !== RESULT_FRAME) return

    const { pageTitle, bikeDetails } = target.querySelector('[data-page-title]')?.dataset ?? {}
    if (pageTitle) document.title = pageTitle
    if (this.#mode === 'model' && bikeDetails) this.#fill(JSON.parse(bikeDetails))
    target.querySelector('[role=status]')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }

  // A model's check is its id alone, and details need a top speed to be one
  get #checkUrl () {
    const fields = new FormData(this.element)
    fields.delete('state')
    if (this.#mode === 'model') DETAILS.forEach((name) => fields.delete(name))
    for (const [name, value] of [...fields]) if (value === '') fields.delete(name)
    if (fields.get('vehicle_models') || fields.get('top_speed')) return `${this.element.action}?${new URLSearchParams(fields)}`
  }

  // Without a check left in the form - a cleared bike - there's nothing to ask the server for
  #check () {
    if (!this.#stateField.value) return this.#awaitState()

    const url = this.#checkUrl
    url ? this.#visit(url) : this.#leaveCheck(this.element.action)
  }

  // The gem announces a prefilled selection on connecting, and Enter then blur both change the panel,
  // neither of which is another check
  #visit (url) {
    if (url === this.lastUrl) return

    this.lastUrl = url
    Turbo.visit(url, { frame: RESULT_FRAME, action: 'advance' })
  }

  // A state's own classes, where it doesn't use the three. The gem announces a prefilled state on connecting,
  // which is the page's own
  #loadClasses () {
    const path = new URL(this.element.action).pathname
    if (path === this.classesPath) return

    this.classesPath = path
    document.getElementById(CLASSES_FRAME).src = path
  }

  // Without a state there's nothing to check a bike against, so it waits in the URL for one
  #awaitState () {
    const url = this.#checkUrl
    this.#leaveCheck(url ?? this.element.action)
    if (!url) return this.stateNoteTarget.replaceChildren()

    // A model's details don't wait: without a state, its frame carries them and no check
    if (this.#mode === 'model') document.getElementById(RESULT_FRAME).src = url

    this.stateNoteTarget.replaceChildren(this.stateNeededTarget.content.cloneNode(true))
    this.focusState()
  }

  #leaveCheck (url) {
    this.lastUrl = url
    document.getElementById(RESULT_FRAME).replaceChildren()
    replaceUrl(new URL(url))
  }

  // Clearing the model clears the details it filled, and leaves custom ones to check on their own
  #clearModel () {
    this.model = ''
    this.legendTarget.textContent = this.legendValue
    if (this.#mode === 'model') this.#fill({})
    this.#setMode('manual')
    this.#check()
  }

  #setMode (mode) {
    this.element.dataset.details = mode
    this.manualTarget.disabled = mode === 'model'
  }

  get #mode () {
    return this.element.dataset.details
  }

  #fill (details) {
    const { elements } = this.element
    for (const name of ['top_speed', 'throttle']) {
      for (const radio of elements[name]) radio.checked = radio.value === String(details[name])
    }
    elements.watts.value = details.watts ?? ''
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
}
