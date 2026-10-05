import { html } from 'lit-html'
import { check, clipboard } from 'bikebook/templates/icons'

const BUTTON_CLASS = 'tw:group tw:shrink-0 tw:cursor-pointer tw:rounded-sm tw:p-1 tw:text-ink/50 tw:hover:bg-vellum tw:hover:text-ink ' +
  'tw:focus:ring-2 tw:focus:ring-gray-400'

// A button copying `value`, its icon a check for a moment after
export const copyButton = ({ value, label }) => html`<button type="button" class=${BUTTON_CLASS} title=${label}
  data-controller="bikebook--copy-button" data-bikebook--copy-button-text-value=${value} data-action="bikebook--copy-button#copy">${
    clipboard({ className: 'tw:h-3.5 tw:w-3.5 tw:group-data-copied:hidden', ariaHidden: true })}${
    check({ className: 'tw:hidden tw:h-3.5 tw:w-3.5 tw:text-green-600 tw:group-data-copied:block', ariaHidden: true })}</button>`
