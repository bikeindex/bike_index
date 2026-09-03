import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

/* global window, Event */

// Connects to data-controller='register--serial'
//
// Mirrors bikes/new serial handling: "Missing serial" fills the input with
// "unknown" and reveals the made-without-a-serial link, whose modal (on
// "I'm 100% sure") swaps the serial section for a made-without checkbox and
// submits the serial as "made_without_serial".
export default class extends Controller {
  static targets = ['input', 'inputRow', 'missing', 'madeWithoutLink', 'serialSection', 'madeWithoutRow', 'madeWithoutCheckbox']

  ABSENT_VALUES = ['unknown', 'made_without_serial']

  connect () {
    this.boundSync = this.syncRestored.bind(this)
    window.addEventListener('form-persist:restored', this.boundSync)
    this.syncRestored()
  }

  disconnect () {
    window.removeEventListener('form-persist:restored', this.boundSync)
  }

  // Reconcile the sections with an absent serial form-persist restored
  syncRestored () {
    if (this.inputTarget.value === 'made_without_serial') {
      this.applyMadeWithout(0)
    } else if (this.inputTarget.value === 'unknown') {
      this.missingTarget.checked = true
      this.applyMissing(0)
    }
  }

  toggleMissing () {
    if (this.missingTarget.checked) {
      this.setSerial('unknown')
      this.applyMissing()
    } else {
      this.restoreSerial()
      collapse('hide', this.madeWithoutLinkTarget)
    }
  }

  // The modal's "I'm 100% sure" button
  confirmMadeWithout () {
    this.setSerial('made_without_serial')
    this.applyMadeWithout()
  }

  // setSerial fills the input first: it's required, and a required field that is
  // display:none while empty blocks submission instead of reporting anything
  applyMissing (duration) {
    collapse('hide', this.inputRowTarget, duration)
    collapse('show', this.madeWithoutLinkTarget, duration)
  }

  applyMadeWithout (duration) {
    this.madeWithoutCheckboxTarget.checked = true
    collapse('hide', this.serialSectionTarget, duration)
    collapse('show', this.madeWithoutRowTarget, duration)
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
    this.dispatchInput()
  }

  // Instantly, so a serialSection animating open around it measures its full height.
  // Both callers mean "the rider is entering a serial again", so it always comes back -
  // including after a made-without confirm hid it on the way past
  restoreSerial () {
    if (this.ABSENT_VALUES.includes(this.inputTarget.value)) {
      this.inputTarget.value = this.stashedSerial || ''
    }
    collapse('show', this.inputRowTarget, 0)
    this.dispatchInput()
  }

  // Programmatic writes fire no events, so form-persist wouldn't see them -
  // notably the modal's confirm, where nothing else fires one either
  dispatchInput () {
    this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }))
  }
}
