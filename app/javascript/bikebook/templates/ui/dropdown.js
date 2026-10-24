import { html } from 'lit-html'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { iconChevron } from 'bikebook/templates/ui/icon_chevron'

// UI::Dropdown::Component in the secondary color, `button` the trigger's content in place of its `name`, and each of
// `entries` a menu item
export const dropdown = ({ name, button = name, buttonSize = 'md', entries }) => {
  const id = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
  return html`<div class="tw:relative tw:inline-flex" data-controller="ui--dropdown"><button type="button" class=${buttonClasses({ size: buttonSize })}
    id=${id} aria-expanded="false" data-action="click->ui--dropdown#toggle" data-ui--dropdown-target="button"><span
    class="tw:sr-only">Open ${name} menu</span>${button}<span class="twdropdown-chevron tw:inline-block tw:transition-transform tw:duration-200">${iconChevron({ direction: 'down' })}</span></button><div
    class="tw:absolute tw:top-0 tw:left-0 tw:hidden tw:w-max tw:max-w-[75vw] tw:min-w-44 tw:rounded-lg tw:border tw:border-gray-200 tw:bg-white
    tw:shadow-lg tw:dark:border-gray-700 tw:dark:bg-gray-800" data-ui--dropdown-target="menu"><ul role="menu" class="twdropdown"
    aria-labelledby=${id}>${entries.map((entry) => html`<li role="menuitem">${entry}</li>`)}</ul></div></div>`
}
