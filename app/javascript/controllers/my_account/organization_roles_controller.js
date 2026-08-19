// Pinned specifier, not relative: under importmap a './' import resolves to a non-digested
// URL that 404s with precompiled assets, so the whole controller would silently never load.
import Sortable from 'controllers/sortable_controller'

// Connects to data-controller='my-account--organization-roles'
// "On by default" is a property of the list's first organization rather than of any one row,
// so the checkbox moves into whichever row a drag leaves on top, and patches that row's URL.
export default class extends Sortable {
  static targets = ['defaultCheckbox', 'defaultSlot']

  reorder (target, after) {
    super.reorder(target, after)
    this.defaultSlotTargets[0].append(this.defaultCheckboxTarget)
  }

  toggleDefault (event) {
    this.patch(this.itemTargets[0].dataset.url, { on_by_default: event.target.checked })
  }
}
