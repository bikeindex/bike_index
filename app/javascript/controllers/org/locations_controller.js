import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'
import { clearCombobox, selectComboboxValue } from 'utils/hw_combobox_patch'

// A new card is always unsaved, and discarding one removes it
const RING = ['tw:ring-2', 'tw:ring-blue-400']
const NOT_SUBMITTED_FIELD = /\[(_destroy|id)\]$/
const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/g
const COUNTRY_SELECT = '[data-ui--forms--address-group-target=country]'

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
    this.listFormat = new Intl.ListFormat(document.documentElement.lang || undefined, { type: 'conjunction' })
  }

  connect () {
    this.locationTargets.forEach((location) => this.snapshots.set(location, this.snapshot(location)))
    this.refreshAll(0)
  }

  add () {
    const index = this.nextIndex++
    const html = this.uniqueIds(this.templateTarget.innerHTML.replaceAll('__INDEX__', index), index)
    this.gridTarget.insertAdjacentHTML('beforeend', html)
    const location = this.gridTarget.lastElementChild
    location.querySelector('[data-slot=name]').focus()
    location.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    this.refreshAll()
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

  // The state combobox renders its option ids as UUIDs, which every clone of the template would share
  uniqueIds (html, index) {
    return html.replace(UUID, (id) => `${id}-${index}`)
  }

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

  currentValue (field) {
    return field.type === 'checkbox' ? field.checked : field.value
  }

  snapshot (location) {
    return this.fields(location).map((field) => this.currentValue(field))
  }

  isDirty (location) {
    if (this.isNew(location) || this.isRemoved(location)) return true

    const saved = this.snapshots.get(location)
    return this.fields(location).some((field, index) => this.currentValue(field) !== saved[index])
  }

  // The country first, since changing it toggles the state and region fields and clears the state
  restore (location) {
    const saved = this.snapshots.get(location)
    const isCountry = (field) => field.matches(COUNTRY_SELECT)
    const entries = this.fields(location).map((field, index) => [field, saved[index]])
      .sort(([first], [second]) => isCountry(second) - isCountry(first))

    entries.forEach(([field, value]) => {
      const combobox = field.closest('.hw-combobox')
      if (combobox) return value ? selectComboboxValue(combobox, value) : clearCombobox(combobox)

      const changed = this.currentValue(field) !== value
      if (field.type === 'checkbox') field.checked = value
      else field.value = value
      if (changed && isCountry(field)) field.dispatchEvent(new Event('change', { bubbles: true }))
    })
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

  refreshAll (duration) {
    const locations = this.locationTargets
    const removable = locations.filter((location) => !this.isRemoved(location)).length > 1
    const showOnMap = this.showOnMap
    const dirtyCount = locations.filter((location) => this.refresh(location, { removable, showOnMap, duration })).length
    this.refreshMap(duration)
    this.refreshSummary(dirtyCount)
  }

  // Returns whether the location has changes, removal counting as one
  refresh (location, { removable, showOnMap, duration }) {
    const removed = this.isRemoved(location)
    const changed = this.isDirty(location)
    const dirty = changed && !removed
    const title = this.titleOf(location)
    const checked = (name) => this.slot(location, name)?.checked
    const impound = checked('impound-check')
    const defaultImpound = impound && checked('default-check')

    this.setShown(this.slot(location, 'active'), !removed, duration)
    this.setShown(this.slot(location, 'removed'), removed, duration)
    this.slot(location, 'removed-name').textContent = title
    this.slot(location, 'title').textContent = title

    this.setRing(location, dirty)
    this.setShown(this.slot(location, 'badge-dirty'), dirty, 0)
    this.setShown(this.slot(location, 'unsaved-row'), dirty, duration)
    this.setShown(this.slot(location, 'badge-map'), showOnMap && checked('public'), 0)
    this.setShown(this.slot(location, 'badge-impound'), impound && !defaultImpound, 0)
    this.setShown(this.slot(location, 'badge-default-impound'), defaultImpound, 0)
    this.setShown(this.slot(location, 'public-row'), showOnMap, duration)
    this.setShown(this.slot(location, 'default-row'), impound, duration)
    this.setShown(this.slot(location, 'remove'), removable, 0)
    return changed
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
    // A locked map has the bar, for Add location, but no checkbox, badge or Save to drive
    if (!this.hasMapCheckboxTarget) return

    const dirty = this.mapDirty
    this.setRing(this.mapBarTarget, dirty)
    this.setShown(this.mapBadgeTarget, dirty, 0)
    this.setShown(this.mapActionsTarget, dirty, duration)
  }

  refreshSummary (dirtyCount) {
    const parts = []
    if (dirtyCount) parts.push(dirtyCount === 1 ? this.oneLocationValue : this.locationsValue.replace('%{count}', dirtyCount))
    if (this.mapDirty) parts.push(this.mapSettingValue)

    this.summaryTarget.textContent = this.summaryValue.replace('%{changes}', this.listFormat.format(parts))
    this.setShown(this.summaryTarget, parts.length > 0, 0)
  }
}
