import { Controller } from '@hotwired/stimulus'

/* global localStorage */

// Connects to data-controller='ui--column-settings'
// Goes on an element holding both a UI::ColumnSettings panel and its table. Each checkbox is
// named for the *_cell class every cell in its column carries.
export default class extends Controller {
  static targets = ['checkbox']
  static values = { storageKey: String, narrowHiddenColumns: Array }

  connect () {
    const stored = this.storedColumns
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = stored ? stored.includes(checkbox.name) : this.isDefault(checkbox)
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
    this.check(checkbox => this.isDefault(checkbox))
  }

  // Saved only from a change, so the defaults a load applies are worked out afresh each time
  update () {
    localStorage.setItem(this.storageKeyValue, JSON.stringify(this.checkedColumns))
    this.showColumns()
  }

  check (checkedFor) {
    this.checkboxTargets.forEach(checkbox => { checkbox.checked = checkedFor(checkbox) })
    this.update()
  }

  showColumns () {
    const checked = this.checkedColumns
    this.checkboxTargets.forEach(({ name }) => {
      this.element.querySelectorAll(`.${name}`).forEach(cell => cell.classList.toggle('tw:hidden', !checked.includes(name)))
    })
    window.dispatchEvent(new Event('ui-table:refresh'))
  }

  // Below Tailwind's sm breakpoint, the narrow-hidden columns aren't defaults
  isDefault (checkbox) {
    if (window.matchMedia('(max-width: 639px)').matches && this.narrowHiddenColumnsValue.includes(checkbox.name)) return false
    return checkbox.dataset.default === 'true'
  }

  get checkedColumns () {
    return this.checkboxTargets.filter(checkbox => checkbox.checked).map(checkbox => checkbox.name)
  }

  get storedColumns () {
    try {
      const columns = JSON.parse(localStorage.getItem(this.storageKeyValue))
      if (columns === null || Array.isArray(columns)) return columns
    } catch {}
    localStorage.removeItem(this.storageKeyValue)
    return null
  }
}
