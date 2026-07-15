import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

// Connects to data-controller='registrations--new--serial'
//
// Mirrors bikes/new serial handling: "Missing serial" fills the input with
// "unknown" and reveals the made-without-a-serial link, whose modal (on
// "I'm 100% sure") swaps the serial section for a made-without checkbox and
// submits the serial as "made_without_serial".
export default class extends Controller {
  static targets = ['input', 'missing', 'madeWithoutLink', 'serialSection', 'madeWithoutRow', 'madeWithoutCheckbox']

  ABSENT_VALUES = ['unknown', 'made_without_serial']

  toggleMissing () {
    if (this.missingTarget.checked) {
      this.setSerial('unknown')
      collapse('show', this.madeWithoutLinkTarget)
    } else {
      this.restoreSerial()
      collapse('hide', this.madeWithoutLinkTarget)
    }
  }

  // The modal's "I'm 100% sure" button
  confirmMadeWithout () {
    this.setSerial('made_without_serial')
    this.madeWithoutCheckboxTarget.checked = true
    collapse('hide', this.serialSectionTarget)
    collapse('show', this.madeWithoutRowTarget)
  }

  // Unchecking "This bike was made without a serial" brings the serial section back
  toggleMadeWithout () {
    if (this.madeWithoutCheckboxTarget.checked) return

    this.restoreSerial()
    this.missingTarget.checked = false
    collapse('hide', this.madeWithoutLinkTarget, 0)
    collapse('hide', this.madeWithoutRowTarget)
    collapse('show', this.serialSectionTarget)
  }

  setSerial (value) {
    if (!this.ABSENT_VALUES.includes(this.inputTarget.value)) {
      this.stashedSerial = this.inputTarget.value
    }
    this.inputTarget.value = value
    this.inputTarget.classList.add('tw:text-gray-400')
  }

  restoreSerial () {
    if (this.ABSENT_VALUES.includes(this.inputTarget.value)) {
      this.inputTarget.value = this.stashedSerial || ''
    }
    this.inputTarget.classList.remove('tw:text-gray-400')
  }
}
