import { Controller } from '@hotwired/stimulus'
import { collapseField } from 'utils/collapse_utils'

// Connects to data-controller='admin--bike-edit-form'
//
// Replaces the serial and recovery behaviors the vendored admin bundle bound to
// `.serial-check input` and `#stolenCheckBox input`:
//   1. The "no serial" checkboxes are mutually exclusive, and each overwrites the serial
//      field with the sentinel Bike#serial_number expects (data-serial), restoring the
//      original value when both are unchecked.
//   2. Unchecking "Bike is stolen" reveals the recovery fields and requires a reason --
//      filling them in is what recovers the bike.
export default class extends Controller {
  static targets = ['serial', 'noSerial', 'stolen', 'recoveryFields', 'recoveryReason']
  static values = { originalSerial: String }

  serialChanged ({ target }) {
    this.noSerialTargets.filter((checkbox) => checkbox !== target).forEach((checkbox) => { checkbox.checked = false })

    this.serialTarget.value = target.checked ? target.dataset.serial : this.originalSerialValue
    this.serialTarget.classList.toggle('fake-disabled', target.checked)
  }

  // collapseField rather than collapse: hiding alone leaves a reason someone typed and
  // then hid still posting, and any reason at all is what recovers the bike
  stolenChanged () {
    const recovering = !this.stolenTarget.checked
    collapseField(this.recoveryFieldsTarget, recovering)
    this.recoveryReasonTarget.required = recovering
  }
}
