import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--organization-form'
//
// Replaces the legacy AdminEdit class from the vendored admin bundle
// (`#admin_organizations_(new|edit)` dispatch is no-op'd there). Two behaviors:
//   1. When the organization "kind" is "ambassador", grey out the ambassador-irrelevant fields.
//   2. When the stolen-message "kind" is "area", reveal the radius field.
export default class extends Controller {
  static targets = [
    'kind',
    'stolenMessageKind',
    'stolenMessageArea',
    'ambassadorField',
    'ambassadorLabel'
  ]

  connect () {
    this.toggleAmbassadorFields()
    this.toggleStolenMessageArea()
  }

  toggleAmbassadorFields () {
    if (!this.hasKindTarget) return
    const ambassador = this.kindTarget.value === 'ambassador'
    this.ambassadorFieldTargets.forEach(el => { el.disabled = ambassador })
    this.ambassadorLabelTargets.forEach(label => label.classList.toggle('text-muted', ambassador))
  }

  toggleStolenMessageArea () {
    if (!this.hasStolenMessageKindTarget || !this.hasStolenMessageAreaTarget) return
    const action = this.stolenMessageKindTarget.value === 'area' ? 'show' : 'hide'
    collapse(action, this.stolenMessageAreaTarget)
  }
}
