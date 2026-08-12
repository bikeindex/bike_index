import HwComboboxController from 'controllers/hw_combobox_controller'

// hotwire_combobox 0.4.1 finds an option by interpolating the raw value into
// `[data-value='<value>']`; a value containing a quote (e.g. a search term like
// `2011'`) builds an invalid selector and throws a SyntaxError, which aborts the
// multiselect reset. Match on the attribute instead so any value is safe.
HwComboboxController.prototype._optionElementWithValue = function (value) {
  return Array.from(
    this._actingListbox.querySelectorAll(`[${this.filterableAttributeValue}]`)
  ).find(option => option.getAttribute('data-value') === value) || null
}

// It also swallows Enter whether or not the listbox is open, so a combobox with
// nothing to pick breaks the form's implicit submission -- unlike every other
// input. Only handle the key while there's an option to choose.
const navigate = HwComboboxController.prototype.navigate
HwComboboxController.prototype.navigate = function (event) {
  if (event.key === 'Enter' && this._isClosed) return

  navigate.call(this, event)
}

// A combobox holding a selection shows its display text, and the caret lands wherever
// the click did -- so typing inserts into the middle, matches no option, and the gem
// clears the hidden field along with the selection the user had

// A gesture at a time, so the click being followed is only ever one element
let clickFocusing = null

const noteClickIntoFocus = ({ currentTarget }) => {
  if (document.activeElement !== currentTarget) clickFocusing = currentTarget
}

// Only the focus a click into the field brings. The gem refocuses the input itself while
// filtering, and selecting on that would make the next keystroke replace the query
const selectDisplay = ({ currentTarget }) => {
  if (clickFocusing === currentTarget && currentTarget.value) currentTarget.select()
}

// The mouseup ending that same click would collapse the selection back to a caret.
// Only that one: a drag leaves a selection of its own, and a later click still places
// the caret, so the display stays editable
const keepSelectionThroughClick = (event) => {
  const input = event.currentTarget
  if (clickFocusing !== input) return

  clickFocusing = null
  if (input.selectionStart === 0 && input.selectionEnd === input.value.length) event.preventDefault()
}

// Stimulus calls these per element, for targets the gem declares but leaves without a
// callback -- the seam that also reaches the small-viewport dialog's own combobox
const listenForClickIntoFocus = function (input) {
  input.addEventListener('mousedown', noteClickIntoFocus)
  input.addEventListener('focus', selectDisplay)
  input.addEventListener('mouseup', keepSelectionThroughClick)
}

HwComboboxController.prototype.comboboxTargetConnected = listenForClickIntoFocus
HwComboboxController.prototype.dialogComboboxTargetConnected = listenForClickIntoFocus
