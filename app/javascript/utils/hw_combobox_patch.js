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
