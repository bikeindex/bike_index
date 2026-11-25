import { Controller } from '@hotwired/stimulus'
import { catalogAt, mountCatalogCombobox, pickedVehicle, showPhoto } from 'bikebook/catalog'
import { soldYears, yearPhoto } from 'bikebook/colorways'

// Connects to data-controller='register--model-lookup'
// The model field as /bikebook's search of the registration's manufacturer's models, once the catalog loads, in place of
// the text field it starts as - what's typed there meanwhile carries over. A pick submits its catalog id, which saving
// the step names it by, fills in the newest year it was sold, and shows its stock photo for the year entered. The year
// stays free to change, as the catalog may not have all of a model's years
export default class extends Controller {
  static targets = ['combobox', 'slot', 'photo', 'year']
  static values = { manifestUrl: String }

  async connect () {
    const loading = catalogAt(this.manifestUrlValue)
    this.catalog = await loading.catch(() => null)
    const standIn = this.slotTarget.querySelector('input')
    const typing = standIn === document.activeElement
    this.comboboxTarget.content.querySelector('input[type=hidden]').value = standIn.value
    // failing, it leaves the text field as it is
    this.field = await mountCatalogCombobox(loading, this.comboboxTarget, this.slotTarget,
      { display: standIn.value, failedText: standIn.placeholder, richPick: true })
    if (typing) this.slotTarget.querySelector('[role=combobox]')?.focus()
    this.pick()
  }

  // The gem preselects the top option as a query's typed, which waits for the selection. A pick restored from a draft
  // keeps its year
  async pick (event) {
    const { type, detail } = event ?? {}
    if (!this.field || (type === 'hw-combobox:preselection' && detail.value && !detail.isNewAndAllowed)) return

    const value = this.field.value
    const picked = await pickedVehicle(this.catalog, value)
    if (value !== this.field.value) return

    this.picked = picked
    const [newest] = picked ? soldYears(picked.data) : []
    if (newest && type === 'hw-combobox:selection') {
      this.yearTarget.value = newest
      // for form-persist's draft
      this.yearTarget.dispatchEvent(new Event('input', { bubbles: true }))
    }
    this.showPhoto()
  }

  // A year typed partway keeps the photo it has
  showPhoto () {
    const year = this.yearTarget.value.trim()
    if (this.field && (!year || /^\d{4}$/.test(year))) {
      showPhoto(this.photoTarget, this.picked, (this.picked && yearPhoto(this.picked.data, Number(year))) ?? null)
    }
  }
}
