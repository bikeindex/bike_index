import { html } from 'lit-html'
import { check, copy } from 'bikebook/templates/icons'
import { tooltip as withTooltip } from 'bikebook/templates/ui/tooltip'

const BUTTON_CLASS = 'tw:group tw:shrink-0 tw:cursor-pointer tw:rounded-sm tw:p-1 tw:text-gray-500 tw:hover:bg-gray-100 tw:hover:text-gray-900 ' +
  'tw:dark:text-gray-400 tw:dark:hover:bg-gray-700 tw:dark:hover:text-gray-100 tw:focus:ring-2 tw:focus:ring-gray-400'

const icons = () => html`${copy('tw:size-3.5 tw:group-data-copied:hidden')}${check('tw:hidden tw:size-3.5 tw:text-green-600 tw:group-data-copied:block')}`

// UI::CopyButton::Component
export const copyButton = ({ value, label, tooltip = false }) => tooltip
  ? withTooltip({
    text: `${label} (${value})`,
    body: html`${label} (<code class="tw:font-mono">${value}</code>)`,
    button: ({ label, id }) => html`<button type="button" class=${BUTTON_CLASS} aria-label=${label} aria-describedby=${id}
      data-ui--tooltip-target="trigger" data-controller="ui--copy-button" data-ui--copy-button-text-value=${value}
      data-action="ui--copy-button#copy">${icons()}</button>`
  })
  : html`<button type="button" class=${BUTTON_CLASS} title=${label} data-controller="ui--copy-button" data-ui--copy-button-text-value=${value}
    data-action="ui--copy-button#copy">${icons()}</button>`
