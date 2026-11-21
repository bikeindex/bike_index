// For a UI::Forms::Group rendered with required_toggleable, which draws both markers
export function toggleRequired (field, required) {
  field.querySelectorAll('input, select, textarea').forEach((el) => { el.required = required })
  field.querySelectorAll('[data-required-marker]').forEach((el) => { el.hidden = !required })
  field.querySelectorAll('[data-optional-marker]').forEach((el) => { el.hidden = required })
}
