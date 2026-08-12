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

const clickedSinceFocus = new WeakSet()

const forgetClicks = ({ currentTarget }) => clickedSinceFocus.delete(currentTarget)

// The entering click, not the focus: step 1 autofocuses its manufacturer, so the first
// click there brings no focus event to hang this on. By click the caret is already placed,
// so the selection sticks without preventing anything, and the gem's own refocus while
// filtering never selects - that would make the next keystroke replace the query
const selectDisplay = ({ currentTarget }) => {
  if (clickedSinceFocus.has(currentTarget)) return

  clickedSinceFocus.add(currentTarget)
  if (currentTarget.value) currentTarget.select()
}

// Stimulus calls these per element, for targets the gem declares but leaves without a
// callback -- the seam that also reaches the small-viewport dialog's own combobox
const listenForClickIntoFocus = function (input) {
  input.addEventListener('focus', forgetClicks)
  input.addEventListener('click', selectDisplay)
}

HwComboboxController.prototype.comboboxTargetConnected = listenForClickIntoFocus
HwComboboxController.prototype.dialogComboboxTargetConnected = listenForClickIntoFocus
