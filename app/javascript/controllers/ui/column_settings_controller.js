import { Controller } from '@hotwired/stimulus'
import { storedArray } from 'utils/stored_array'

/* global localStorage */

// Connects to data-controller='ui--column-settings'
// Goes on an element holding both a UI::ColumnSettings panel and its table. Each checkbox is
// named for the *_cell class every cell in its column carries.
export default class extends Controller {
  static targets = ['checkbox']
  static values = { storageKey: String }

  connect () {
    const stored = storedArray(this.storageKeyValue)
    const isDefault = this.isDefault
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = stored ? stored.includes(checkbox.name) : isDefault(checkbox)
    })
    this.showColumns()
  }

  selectAll () {
    this.check(() => true)
  }

  selectNone () {
    this.check(() => false)
  }

  selectDefault () {
    this.check(this.isDefault)
  }

  // Saved only from a change, so the defaults a load applies are worked out afresh each time
  update () {
    const checked = this.checkboxTargets.filter(checkbox => checkbox.checked).map(checkbox => checkbox.name)
    localStorage.setItem(this.storageKeyValue, JSON.stringify(checked))
    this.showColumns()
  }

  check (checkedFor) {
    this.checkboxTargets.forEach(checkbox => { checkbox.checked = checkedFor(checkbox) })
    this.update()
  }

  showColumns () {
    this.checkboxTargets.forEach(({ name, checked }) => {
      this.element.querySelectorAll(`.${name}`).forEach(cell => cell.classList.toggle('tw:hidden', !checked))
    })
    window.dispatchEvent(new Event('ui-table:refresh'))
  }

  // Below Tailwind's sm breakpoint, the narrow-hidden columns aren't defaults
  get isDefault () {
    const narrow = window.matchMedia('(max-width: 639px)').matches
    return ({ dataset }) => dataset.default === 'true' && !(narrow && dataset.narrowHidden === 'true')
  }
}
