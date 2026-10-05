import { html, nothing } from 'lit-html'
import { randomHex } from 'bikebook/templates/helpers'

const TRIGGER_ACTIONS = 'mouseenter->ui--tooltip#showOnHover mouseleave->ui--tooltip#hideOnHover ' +
  'focusin->ui--tooltip#showPersistent click->ui--tooltip#showPersistent focusout->ui--tooltip#hideOnFocusout'
const TRIGGER_CLASS = 'tw:inline-block tw:rounded tw:cursor-help tw:focus:outline-none tw:focus:ring-3 tw:focus:ring-blue-500/40'
const BUTTON_CLASS = 'keep-with-previous tw:inline-flex tw:items-center tw:justify-center tw:h-4 tw:w-4 tw:rounded-full ' +
  'tw:bg-gray-200 tw:text-gray-700 tw:hover:bg-gray-300 tw:dark:bg-gray-700 tw:dark:text-gray-200 tw:dark:hover:bg-gray-600 ' +
  'tw:text-2xs tw:font-bold tw:cursor-help tw:focus:outline-none tw:focus:ring-3 tw:focus:ring-blue-500/40'
const SURFACE_CLASS = 'tw:bg-white tw:border-gray-200 tw:dark:bg-gray-800 tw:dark:border-gray-700'

// UI::Tooltip::Component. `content` is the trigger, the "?" button without it; `body` fills the
// tooltip in place of `text`
export const tooltip = ({ text, body, content }) => {
  const id = `tooltip-${randomHex(4)}`
  return html`<span class="tw:inline-block" data-controller="ui--tooltip" data-action=${TRIGGER_ACTIONS}><button type="button"
    aria-label=${text || nothing} aria-describedby=${id} data-ui--tooltip-target="trigger"
    class=${content ? TRIGGER_CLASS : BUTTON_CLASS}>${content ?? '?'}</button> <span role="tooltip" id=${id}
    data-ui--tooltip-target="tooltip" class="tw:twtext-color tw:hidden tw:pointer-events-none tw:whitespace-nowrap tw:text-left tw:rounded
    tw:px-2 tw:py-1 tw:font-sans tw:text-xs tw:font-normal tw:normal-case tw:border tw:shadow-lg tw:z-50 ${SURFACE_CLASS}">${body ?? text}<span
    aria-hidden="true" data-ui--tooltip-target="arrow" class="tw:absolute tw:h-2 tw:w-2 tw:rotate-45 tw:border-solid ${SURFACE_CLASS}"></span></span></span>`
}
