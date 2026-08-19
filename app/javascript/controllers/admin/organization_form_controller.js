import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--organization-form'
//
// Replaces the legacy AdminEdit class from the vendored admin bundle
// (`#admin_organizations_(new|edit)` dispatch is no-op'd there). Two behaviors:
//   1. When the organization "kind" is "ambassador", grey out the ambassador-irrelevant fields.
//   2. When the stolen-message "kind" is "area", reveal the radius field.
//   3. When SAML SSO is enabled, star the IdP fields the model then requires.
export default class extends Controller {
  static targets = [
    'kind',
    'stolenMessageKind',
    'stolenMessageArea',
    'ambassadorField',
    'ambassadorLabel',
    'samlEnabled',
    'samlRequiredFields'
  ]

  connect () {
    this.toggleAmbassadorFields()
    this.toggleStolenMessageArea()
    this.toggleSamlRequired()
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

  // OrganizationSamlConfiguration validates these present when enabled, so an unchecked
  // box is the one state where a half-filled configuration saves
  toggleSamlRequired () {
    if (!this.hasSamlEnabledTarget || !this.hasSamlRequiredFieldsTarget) return
    const required = this.samlEnabledTarget.checked
    const fields = this.samlRequiredFieldsTarget
    fields.querySelectorAll('input, textarea').forEach((el) => { el.required = required })
    fields.querySelectorAll('[data-required-marker]').forEach((el) => { el.hidden = !required })
    fields.querySelectorAll('[data-optional-marker]').forEach((el) => { el.hidden = required })
  }
}
