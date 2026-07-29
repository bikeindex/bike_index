import { Controller } from '@hotwired/stimulus'

// Connects to data-controller='ui--forms--combobox-display'
// (rendered by UI::Forms::Combobox rich_display:)
//
// Renders the selected combobox option's rich content - a muted parenthetical,
// or a muted second line. An <input> can't render either, so a mirror overlay
// covers it, cloning the option's listbox content so the formatting has a
// single source. Focus alone doesn't drop the overlay (that would blank the
// display on a click); it steps aside once the input holds a filter query.
export default class extends Controller {
  static targets = ['overlay']

  connect () {
    this.input = this.element.querySelector('.hw-combobox__input')
    this.hiddenField = this.element.querySelector('input[data-hw-combobox-target="hiddenField"]')
    // Read before the overlay ever paints the input transparent
    this.caretColor = window.getComputedStyle(this.input).color
    this.events().forEach(([target, event]) => target.addEventListener(event, this.sync))
    window.addEventListener('resize', this.onResize)
    this.sync()
  }

  disconnect () {
    this.events().forEach(([target, event]) => target.removeEventListener(event, this.sync))
    window.removeEventListener('resize', this.onResize)
  }

  // keyup catches arrow-key navigation, which sets the value without an input
  // event; click catches the handle clearing the selection, which deselects
  // silently; form-persist assigns a restored selection with no event of its own
  events () {
    return [
      [this.input, 'input'], [this.input, 'keyup'], [this.input, 'blur'],
      [this.element, 'click'], [this.element, 'hw-combobox:selection'],
      [window, 'form-persist:restored']
    ]
  }

  // input and keyup both fire per keystroke, so bail before repainting (and before
  // reposition's forced layout) unless what's shown would actually change
  sync = () => {
    const selectedOption = this.selectedOption()
    const shown = (!selectedOption || this.typingQuery(selectedOption)) ? null : selectedOption
    if (shown === this.shown) return
    if (!shown) { this.hide(); return }

    this.shown = shown
    this.overlayTarget.innerHTML = shown.innerHTML
    this.reposition()
    Object.assign(this.input.style, { color: 'transparent', caretColor: this.caretColor })
    // combobox.css hides the autocomplete's selection highlight while covered
    this.input.dataset.richDisplayShown = ''
    this.overlayTarget.classList.remove('tw:hidden')
  }

  // Anything but the selection in the input is a query - let it show through.
  // Only while the input has focus: the small-viewport dialog selects without
  // ever focusing it, and fills its value after the selection event.
  typingQuery (selectedOption) {
    return document.activeElement === this.input &&
      this.input.value !== selectedOption.dataset.autocompletableAs
  }

  hide = () => {
    this.shown = null
    Object.assign(this.input.style, { color: '', caretColor: '' })
    delete this.input.dataset.richDisplayShown
    this.overlayTarget.classList.add('tw:hidden')
  }

  onResize = () => {
    if (this.overlayTarget.classList.contains('tw:hidden')) return

    this.reposition()
  }

  // Matched on the attribute rather than a `[data-value="…"]` selector, which a
  // value containing a quote would make invalid (see utils/hw_combobox_patch.js)
  selectedOption () {
    const value = this.hiddenField?.value
    if (!value) return null

    return [...this.element.querySelectorAll('[role="option"]')]
      .find((option) => option.dataset.value === value)
  }

  reposition () {
    const inputRect = this.input.getBoundingClientRect()
    const wrapperRect = this.element.getBoundingClientRect()
    const computed = window.getComputedStyle(this.input)
    Object.assign(this.overlayTarget.style, {
      top: `${inputRect.top - wrapperRect.top}px`,
      left: `${inputRect.left - wrapperRect.left}px`,
      width: `${inputRect.width}px`,
      height: `${inputRect.height}px`,
      font: computed.font,
      paddingLeft: computed.paddingLeft,
      paddingRight: computed.paddingRight,
      paddingTop: computed.paddingTop,
      paddingBottom: computed.paddingBottom
    })
  }
}
