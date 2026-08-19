// Pinned specifier, not relative: under importmap a './' import resolves to a non-digested
// URL that 404s with precompiled assets, so the whole controller would silently never load.
import Sortable from 'controllers/sortable_controller'

// Connects to data-controller='my-account--organization-roles'
// The "use on login" checkbox names whichever organization is first, so a drag that changes
// which one that is rewrites the name -- the row order is already what the server was sent.
export default class extends Sortable {
  static targets = ['organizationName']

  reorder (target, after) {
    super.reorder(target, after)
    this.organizationNameTarget.textContent = this.itemTargets[0].dataset.organizationName
  }
}
