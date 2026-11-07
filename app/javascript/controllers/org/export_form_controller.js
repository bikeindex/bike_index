import { Controller } from '@hotwired/stimulus'
import { collapse } from 'utils/collapse_utils'

const anyChecked = (checkboxes) => checkboxes.some((checkbox) => checkbox.checked)

// Connects to data-controller='org--export-form'
// Shows the fields that apply to the kind of export selected
export default class extends Controller {
  static targets = ['averyCheckbox', 'assignStickersCheckbox', 'stickerField', 'hiddenOnAvery', 'onlyCustomCheckbox',
    'hiddenOnOnlyCustom', 'partialCheckbox']

  // Unanimated, since a re-rendered form or a browser's restored checkboxes can start checked
  connect () {
    this.update({ duration: 0 })
  }

  update ({ duration } = {}) {
    const avery = anyChecked(this.averyCheckboxTargets)
    collapse(avery ? 'hide' : 'show', this.hiddenOnAveryTargets, duration)
    collapse(avery || anyChecked(this.assignStickersCheckboxTargets) ? 'show' : 'hide', this.stickerFieldTargets, duration)
    collapse(anyChecked(this.onlyCustomCheckboxTargets) ? 'hide' : 'show', this.hiddenOnOnlyCustomTargets, duration)
  }

  selectOnlyCustom () {
    if (anyChecked(this.partialCheckboxTargets)) return

    this.onlyCustomCheckboxTarget.checked = true
    this.update()
  }
}
