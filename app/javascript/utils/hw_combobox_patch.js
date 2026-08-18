import HwComboboxController from 'controllers/hw_combobox_controller'

/* global AbortController, requestAnimationFrame */

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

// ArrowUp doesn't open a closed combobox the way ArrowDown does, so it picks out of a
// hidden listbox -- and the gem's wrap-around hands back `undefined` for an empty list.
const selectIndex = HwComboboxController.prototype._selectIndex
HwComboboxController.prototype._selectIndex = function (index) {
  if (this._visibleOptionElements.length) selectIndex.call(this, index)
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

// The dialog is the small-screen picker, but the gem measures the window the combobox is
// in - so an iframe narrower than the breakpoint got it on a desktop, where it can't
// escape the frame to be full-screen anyway.
const isSmallViewport = (query) => {
  // Lookbook frames its previews, and dragging its viewport handle is how they're reviewed
  if (window.inComponentPreview) return window.matchMedia(query).matches

  try {
    return window.top.matchMedia(query).matches
  } catch {
    return window.matchMedia(query).matches // a cross-origin top isn't readable to measure
  }
}

// Shadows an inherited accessor, so it can't be a plain assignment like the patches above
Object.defineProperty(HwComboboxController.prototype, '_isSmallViewport', {
  configurable: true,
  get () {
    return isSmallViewport(`(max-width: ${this.smallViewportMaxWidthValue})`)
  }
})

// Neither covers the other: only `before-cache` runs early enough to keep an open dialog
// out of a cached snapshot, and it's skipped on the no-cache pages the comboboxes are on
const RENDER_EVENTS = ['turbo:before-cache', 'turbo:before-render']

// On small viewports it opens in a modal dialog and locks body scroll, but only
// unlocks along its own collapse path, which a keypress or a click has to start.
// Neither way a phone leaves the dialog starts one -- Android's back gesture closes it,
// iOS's back swipe navigates away -- and iOS takes its lock out on document, so the
// page it lands on is stranded unscrollable too.
const openInDialog = HwComboboxController.prototype._openInDialog
HwComboboxController.prototype._openInDialog = function () {
  openInDialog.call(this)

  const listeners = new AbortController()
  const dismiss = () => {
    listeners.abort() // the close below re-enters here otherwise
    if (!this.expandedValue) return // its own collapse path already ran

    // The browser sends this same close request for Escape, so close the way escape
    // does -- tearing the dialog down by hand instead leaves a typed query sitting in
    // the field with nothing selected behind it
    this.close('hw:keyHandler:escape')
    // `close` collapsed inline, the dialog already being shut, so its half is still owed
    this._moveArtifactsInline()
    this._restoreBodyScroll()
    // iOS pins the body from inside a requestAnimationFrame, and this restore doesn't
    // wait for it -- a lock taken and released within one frame lands after its own
    // release and stays. Ours is queued second, so it runs once the pin is on.
    requestAnimationFrame(() => this._restoreBodyScroll())
  }

  this.dialogTarget.addEventListener('close', dismiss, { signal: listeners.signal })
  RENDER_EVENTS.forEach(name => document.addEventListener(name, dismiss, { signal: listeners.signal }))
}
