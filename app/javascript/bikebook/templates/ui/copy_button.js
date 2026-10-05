import { html } from 'lit-html'
import { check, copy } from 'bikebook/templates/icons'

const BUTTON_CLASS = 'tw:group tw:shrink-0 tw:cursor-pointer tw:rounded-sm tw:p-1 tw:text-gray-500 tw:hover:bg-gray-100 tw:hover:text-gray-900 ' +
  'tw:dark:text-gray-400 tw:dark:hover:bg-gray-700 tw:dark:hover:text-gray-100 tw:focus:ring-2 tw:focus:ring-gray-400'

// UI::CopyButton::Component
export const copyButton = ({ value, label }) => html`<button type="button" class=${BUTTON_CLASS} title=${label}
  data-controller="ui--copy-button" data-ui--copy-button-text-value=${value} data-action="ui--copy-button#copy">${
    copy('tw:size-3.5 tw:group-data-copied:hidden')}${check('tw:hidden tw:size-3.5 tw:text-green-600 tw:group-data-copied:block')}</button>`
