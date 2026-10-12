import { html, nothing } from 'lit-html'
import { blank } from 'bikebook/templates/values'

// UI::DefinitionList::Row::Component, for the label-and-value rows the browser renders; it renders
// nothing without a value or content
export const definitionListRow = ({ label, value, content }) => blank(value) && blank(content)
  ? nothing
  : html`<div class="tw:flex tw:items-baseline tw:justify-between tw:gap-x-4 tw:pt-3 tw:leading-tight"><dt
    class="tw:flex-none tw:text-sm tw:leading-tight tw:opacity-65">${label}</dt><dd class="tw:mb-0 tw:text-right">${value}${content}</dd></div>`
