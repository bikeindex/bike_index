import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--social-post-form'
//
// Nothing had been driving this form: the vendored admin bundle's tweet module is guarded
// on #tweetForm, an id the page lost when tweets became social posts.
export default class extends Controller {
  static targets = ['kind', 'kindFields', 'accountCheckbox']

  kindChanged () {
    this.kindFieldsTargets.forEach((fields) =>
      collapse(fields.dataset.kind === this.kindTarget.value ? 'show' : 'hide', fields))
  }

  checkAll () {
    this.setAccountsChecked(true)
  }

  uncheckAll () {
    this.setAccountsChecked(false)
  }

  setAccountsChecked (checked) {
    this.accountCheckboxTargets.forEach((checkbox) => { checkbox.checked = checked })
  }
}
