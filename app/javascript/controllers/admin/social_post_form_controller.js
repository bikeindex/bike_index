import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--social-post-form'
//
// The vendored admin bundle's tweet module bound all of this to #tweetForm, an id the
// page lost when tweets became social posts - so the kind select, the repost select-all
// and the character count have all been inert since. Kind decides which half of the form
// applies: sending a post takes an account and a body, importing one takes a platform ID.
export default class extends Controller {
  static targets = ['kind', 'kindFields', 'characterCounter', 'characterTotal', 'accountCheckbox']
  static values = { maxCharacterCount: Number }

  connect () {
    this.setCharacterCount()
  }

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

  updateCharacterCount () {
    this.setCharacterCount()
  }

  setAccountsChecked (checked) {
    this.accountCheckboxTargets.forEach((checkbox) => { checkbox.checked = checked })
  }

  setCharacterCount () {
    this.characterTotalTarget.textContent = `${this.characterCounterTarget.value.length}/${this.maxCharacterCountValue}`
  }
}
