import { Controller } from '@hotwired/stimulus'
import { html, nothing } from 'lit-html'
import { catalogAt, mountCatalogCombobox, showPickedPhoto } from 'bikebook/catalog'
import { renderInto } from 'bikebook/render'

// Newest first, every year it was sold rather than only those the catalog has a record of: through its final year, or
// for a current model its newest record
const yearsOf = ({ first_year: first, final_year: final, years = [] }) => {
  const last = final ?? Math.max(first, ...years.map(({ year }) => year))
  return first ? Array.from({ length: last - first + 1 }, (_, index) => last - index) : []
}

// Connects to data-controller='register--model-lookup'
// The model field as /bikebook's search of the registration's manufacturer's models, once the catalog loads, in place of
// the text field it starts as - what's typed there meanwhile carries over. A pick submits its catalog id, which saving
// the step names it by, shows its stock photo, and makes the year a select of its years
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
    this.yearSelect = document.createElement('span')
    this.yearTarget.after(this.yearSelect)
    this.pick()
  }

  // The gem preselects the top option as a query's typed, which waits for the selection. A pick restored from a draft
  // keeps its year
  async pick (event) {
    const { type, detail } = event ?? {}
    if (!this.field || (type === 'hw-combobox:preselection' && detail.value && !detail.isNewAndAllowed)) return

    const picked = await showPickedPhoto(this.catalog, this.field.value, this.photoTarget)
    if (picked !== undefined) this.offerYears(picked ? yearsOf(picked.data) : [], type === 'hw-combobox:selection')
  }

  // In place of the year's text field, which keeps what's chosen for a pick replaced by typed text
  offerYears (years, fresh) {
    const year = this.yearTarget
    this.yearId ??= year.id
    const chosen = years.includes(Number(year.value)) && !fresh ? Number(year.value) : years[0]
    if (years.length) year.value = chosen
    // the select takes the field's id while it's shown, which the label is for
    Object.assign(year, { hidden: years.length > 0, disabled: years.length > 0, id: years.length ? '' : this.yearId })
    renderInto(this.yearSelect, years.length
      ? html`<select class="twinput tw:font-mono" id=${this.yearId} name=${year.name}
          @change=${({ target }) => { year.value = target.value }}>${years.map((each) => html`<option value=${each}
          ?selected=${each === chosen}>${each}</option>`)}</select>`
      : nothing)
  }
}
