import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='admin--user-edit-form'
//
// Checking "banned" opens the ban panel and makes a reason mandatory. The fields are
// hidden rather than disabled, so an abandoned ban posts what it always did.
export default class extends Controller {
  static targets = ['banned', 'banFields', 'banReason']

  bannedChanged () {
    const banning = this.bannedTarget.checked

    collapse(banning ? 'show' : 'hide', this.banFieldsTargets)
    if (this.hasBanReasonTarget) this.banReasonTarget.required = banning
  }
}
