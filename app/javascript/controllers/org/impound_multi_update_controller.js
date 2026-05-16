import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='org--impound-multi-update'
//
// Restores the legacy BinxAppOrgImpoundRecords index behavior now that the
// impound records table loads inside a turbo-frame: the legacy jQuery handlers
// were bound on initial page load and never see the frame's content. Stimulus
// reconnects this controller every time the frame re-renders.
export default class extends Controller {
  connect () {
    this.toggleLink = this.element.querySelector('#toggleMultiUpdate')
    this.selectAllLink = this.element.querySelector('#selectAllSelector')
    this.kindSelect = this.element.querySelector('#impoundRecordUpdateForm #impound_record_update_kind')

    this.toggleLink?.addEventListener('click', this.revealMultiselect)
    this.selectAllLink?.addEventListener('click', this.toggleAllChecked)
    this.kindSelect?.addEventListener('change', this.updateKind)

    this.updateKind()
  }

  disconnect () {
    this.toggleLink?.removeEventListener('click', this.revealMultiselect)
    this.selectAllLink?.removeEventListener('click', this.toggleAllChecked)
    this.kindSelect?.removeEventListener('change', this.updateKind)
  }

  // Bootstrap's data-toggle handles the #makeMultiUpdate panel; this reveals
  // the otherwise-collapsed checkbox column and hides the toggle link.
  revealMultiselect = () => {
    this.toggleLink.style.display = 'none'
    this.multiselectCells.forEach((cell) => cell.classList.remove('collapse'))
  }

  toggleAllChecked = (event) => {
    event.preventDefault()
    this.allChecked = !this.allChecked
    // Only the currently-updatable rows
    this.element
      .querySelectorAll(`.multiselect-cell.canupdate-${this.currentKind} input`)
      .forEach((input) => { input.checked = this.allChecked })
  }

  updateKind = () => {
    const kind = this.currentKind

    this.element.querySelectorAll('#impoundRecordUpdateForm .collapseKind').forEach((field) => {
      const matches = field.classList.contains(`kind_${kind}`)
      field.classList.toggle('show', matches)
      field.classList.toggle('in', matches)
    })

    this.updateDisabledChecks(kind)
  }

  // Disable checkboxes on rows that can't take the selected kind
  updateDisabledChecks (kind) {
    const humanizedKind = this.kindSelect?.selectedOptions[0]?.text
    this.multiselectCells.forEach((cell) => {
      const canUpdate = cell.classList.contains(`canupdate-${kind}`)
      cell.classList.toggle('disabledCell', !canUpdate)
      cell.querySelectorAll('input').forEach((input) => {
        input.disabled = !canUpdate
        if (!canUpdate) input.checked = false
      })
      cell.title = canUpdate ? '' : `This record can't be updated with '${humanizedKind}'`
    })
  }

  get multiselectCells () {
    return this.element.querySelectorAll('.multiselect-cell')
  }

  get currentKind () {
    return this.kindSelect?.value
  }
}
