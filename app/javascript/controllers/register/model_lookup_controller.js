import { Controller } from '@hotwired/stimulus'
import { catalogAt, mountCatalogCombobox, showPickedPhoto } from 'bikebook/catalog'

// Connects to data-controller='register--model-lookup'
// The model field as /bikebook's search of the registration's manufacturer's models, once the catalog loads, in place of
// the text field it starts as - what's typed there meanwhile carries over. A pick submits its catalog id, which saving
// the step names it by, and shows its stock photo
export default class extends Controller {
  static targets = ['combobox', 'slot', 'photo']
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

  pick () {
    if (this.field) showPickedPhoto(this.catalog, this.field.value, this.photoTarget)
  }
}
