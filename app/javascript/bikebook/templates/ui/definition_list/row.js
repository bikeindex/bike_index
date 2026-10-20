import { html, nothing } from 'lit-html'
import { blank } from 'bikebook/templates/values'

// UI::DefinitionList::Row::Component, for the label-and-value rows the browser renders; it renders nothing without a
// value or content, or `noValueText` in their place, as render_with_no_value and no_value_text do
export const definitionListRow = ({ label, value, content, noValueText }) => {
  const empty = blank(value) && blank(content)
  if (empty && noValueText == null) return nothing

  return html`<div class="tw:flex tw:items-baseline tw:justify-between tw:gap-x-4 tw:pt-3 tw:leading-tight"><dt
    class="tw:flex-none tw:text-sm tw:leading-tight tw:opacity-65">${label}</dt><dd class="tw:mb-0 tw:text-right">${empty
      ? html`<span class="tw:text-xs tw:opacity-50">${noValueText}</span>`
      : html`${value}${content}`}</dd></div>`
}
