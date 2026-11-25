import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'
import { clearCombobox, selectComboboxValue } from 'utils/hw_combobox_patch'

// Connects to data-controller='org--locations' on the locations form
//
// Every Save button submits the same form, so this only tracks what differs from the page load:
// a card's fields against a snapshot, the map checkbox against its default. A card's pieces are
// found by data-slot within it. A new card is always unsaved; discarding one removes it.
const RING = ['tw:ring-2', 'tw:ring-blue-400']
const NOT_SUBMITTED_FIELD = /\[(_destroy|id)\]$/

export default class extends Controller {
  static targets = ['location', 'grid', 'template', 'mapCheckbox', 'mapBar', 'mapBadge', 'mapActions', 'summary']
  static values = {
    showOnMap: Boolean,
    summary: String,
    oneLocation: String,
    locations: String,
    mapSetting: String
  }

  initialize () {
    this.nextIndex = Date.now()
    this.snapshots = new WeakMap()
  }

  locationTargetConnected (location) {
    this.snapshots.set(location, this.snapshot(location))
    this.refreshAll(0)
  }

  add () {
    const html = this.templateTarget.innerHTML.replaceAll('__INDEX__', this.nextIndex++)
    this.gridTarget.insertAdjacentHTML('beforeend', html)
    const location = this.gridTarget.lastElementChild
    location.querySelector('[data-slot=name]').focus()
    location.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }

  changed (event) {
    const location = event.target.closest('[data-new-record]')
    if (location) this.syncImpound(location, event.target)

    this.refreshAll()
  }

  remove (event) {
    const location = this.locationFor(event)
    // Nothing saved to destroy, and a hidden required field would block the submit
    if (this.isNew(location)) return this.dropNew(location)

    location.querySelector('[data-slot=destroy]').value = '1'
    location.querySelectorAll('[required]').forEach((field) => {
      field.dataset.wasRequired = true
      field.required = false
    })
    this.refreshAll()
  }

  undo (event) {
    const location = this.locationFor(event)
    location.querySelector('[data-slot=destroy]').value = 'false'
    location.querySelectorAll('[data-was-required]').forEach((field) => {
      field.required = true
      delete field.dataset.wasRequired
    })
    this.refreshAll()
  }

  discard (event) {
    const location = this.locationFor(event)
    if (this.isNew(location)) return this.dropNew(location)

    this.restore(location)
    this.refreshAll()
  }

  discardMap () {
    this.mapCheckboxTarget.checked = this.mapCheckboxTarget.defaultChecked
    this.refreshAll()
  }

  // private

  locationFor (event) {
    return event.currentTarget.closest('[data-new-record]')
  }

  isNew (location) {
    return location.dataset.newRecord === 'true'
  }

  isRemoved (location) {
    return location.querySelector('[data-slot=destroy]')?.value === '1'
  }

  dropNew (location) {
    location.remove()
    this.refreshAll()
  }

  // What a card submits, in document order - the _destroy and id fields excluded. A combobox's
  // value is in its hidden field, so that's snapshotted with the rest
  fields (location) {
    return [...location.querySelectorAll('input[name], select[name]')]
      .filter((field) => !NOT_SUBMITTED_FIELD.test(field.name))
  }

  valueOf (field) {
    return field.type === 'checkbox' ? field.checked : field.value
  }

  snapshot (location) {
    return this.fields(location).map((field) => this.valueOf(field))
  }

  isDirty (location) {
    if (this.isNew(location) || this.isRemoved(location)) return true

    // A card that hasn't connected yet has no snapshot, and nothing edited
    const saved = this.snapshots.get(location)
    return !!saved && this.fields(location).some((field, index) => this.valueOf(field) !== saved[index])
  }

  // The country first, since changing it toggles the state and region fields and clears the state
  restore (location) {
    const saved = this.snapshots.get(location)
    const entries = this.fields(location).map((field, index) => [field, saved[index]])
    const isCountry = ([field]) => field.matches('select') && !field.closest('.hw-combobox')
    const ordered = [...entries.filter(isCountry), ...entries.filter((entry) => !isCountry(entry))]

    ordered.forEach(([field, value]) => {
      const combobox = field.closest('.hw-combobox')
      if (combobox) return value ? selectComboboxValue(combobox, value) : clearCombobox(combobox)

      if (field.type === 'checkbox') field.checked = value
      else field.value = value
      if (isCountry([field])) field.dispatchEvent(new Event('change', { bubbles: true }))
    })
    this.syncImpound(location, null)
  }

  // The default can't outlive its impound location, and there's only one of it
  syncImpound (location, changed) {
    const impound = location.querySelector('[data-slot=impound-check]')
    const defaultCheck = location.querySelector('[data-slot=default-check]')
    if (!impound) return

    if (!impound.checked) defaultCheck.checked = false
    if (changed === defaultCheck && defaultCheck.checked) {
      this.locationTargets.forEach((other) => {
        if (other !== location) other.querySelector('[data-slot=default-check]').checked = false
      })
    }
  }

  get showOnMap () {
    return this.hasMapCheckboxTarget ? this.mapCheckboxTarget.checked : this.showOnMapValue
  }

  setShown (element, shown, duration) {
    if (element) collapse(shown ? 'show' : 'hide', element, duration)
  }

  slot (location, name) {
    return location.querySelector(`[data-slot=${name}]`)
  }

  refreshAll (duration = undefined) {
    const locations = this.locationTargets.filter((location) => location.isConnected)
    const removable = locations.filter((location) => !this.isRemoved(location)).length > 1
    locations.forEach((location) => this.refresh(location, removable, duration))
    this.refreshMap(duration)
    this.refreshSummary(locations)
  }

  refresh (location, removable, duration) {
    const removed = this.isRemoved(location)
    const dirty = this.isDirty(location) && !removed
    const checked = (name) => this.slot(location, name)?.checked
    const impound = checked('impound-check')
    const defaultImpound = impound && checked('default-check')

    this.setShown(this.slot(location, 'active'), !removed, duration)
    this.setShown(this.slot(location, 'removed'), removed, duration)
    this.slot(location, 'removed-name').textContent = this.titleOf(location)
    this.slot(location, 'title').textContent = this.titleOf(location)

    this.setRing(location, dirty)
    this.setShown(this.slot(location, 'badge-dirty'), dirty, 0)
    this.setShown(this.slot(location, 'unsaved-row'), dirty, duration)
    this.setShown(this.slot(location, 'badge-map'), this.showOnMap && checked('public'), 0)
    this.setShown(this.slot(location, 'badge-impound'), impound && !defaultImpound, 0)
    this.setShown(this.slot(location, 'badge-default-impound'), defaultImpound, 0)
    this.setShown(this.slot(location, 'public-row'), this.showOnMap, duration)
    this.setShown(this.slot(location, 'default-row'), impound, duration)
    this.setShown(this.slot(location, 'remove'), removable, 0)
  }

  setRing (element, on) {
    RING.forEach((name) => element.classList.toggle(name, on))
  }

  titleOf (location) {
    const title = this.slot(location, 'title')
    return this.slot(location, 'name').value.trim() || title.dataset.fallback
  }

  get mapDirty () {
    return this.hasMapCheckboxTarget && this.mapCheckboxTarget.checked !== this.mapCheckboxTarget.defaultChecked
  }

  refreshMap (duration) {
    if (!this.hasMapBarTarget) return

    this.setRing(this.mapBarTarget, this.mapDirty)
    this.setShown(this.mapBadgeTarget, this.mapDirty, 0)
    this.setShown(this.mapActionsTarget, this.mapDirty, duration)
  }

  refreshSummary (locations) {
    const changed = locations.filter((location) => this.isDirty(location)).length
    const parts = []
    if (changed) parts.push(changed === 1 ? this.oneLocationValue : this.locationsValue.replace('%{count}', changed))
    if (this.mapDirty) parts.push(this.mapSettingValue)

    const list = new Intl.ListFormat(document.documentElement.lang || undefined, { type: 'conjunction' })
    this.summaryTarget.textContent = this.summaryValue.replace('%{changes}', list.format(parts))
    this.setShown(this.summaryTarget, parts.length > 0, 0)
  }
}
