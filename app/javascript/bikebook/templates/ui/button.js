import { html } from 'lit-html'
import { attributes } from 'bikebook/templates/attributes'

const BASE_CLASSES = 'tw:inline-flex tw:items-center tw:justify-center tw:gap-1.5 tw:cursor-pointer'
const STANDARD_SHAPE = 'tw:rounded-lg tw:font-medium tw:transition-colors'
const SIZES = { sm: `${STANDARD_SHAPE} tw:px-2.5 tw:py-1 tw:text-xs`, md: `${STANDARD_SHAPE} tw:px-3 tw:py-1.5 tw:text-sm` }
const COLORS = {
  secondary: 'tw:text-gray-800 tw:bg-white tw:border tw:border-gray-200 tw:not-disabled:not-aria-disabled:hover:border-purple-500 ' +
    'tw:not-disabled:not-aria-disabled:hover:bg-purple-50 tw:focus:ring-purple-500/40 tw:dark:bg-gray-800 tw:dark:text-gray-100 ' +
    'tw:dark:border-gray-700 tw:dark:not-disabled:not-aria-disabled:hover:border-purple-500 tw:dark:not-disabled:not-aria-disabled:hover:bg-purple-950'
}
const ACTIVE_COLORS = {
  secondary: 'tw:is-active:text-white tw:is-active:bg-purple-500 tw:is-active:border-purple-500 tw:is-active:ring-2 tw:is-active:ring-purple-500/40'
}
const DISABLED_CLASSES = 'tw:disabled:opacity-50 tw:disabled:cursor-not-allowed tw:aria-disabled:opacity-50 tw:aria-disabled:cursor-not-allowed'
const FOCUS_CLASSES = 'tw:focus:outline-none tw:focus:ring-3 tw:is-active:focus:ring-3'

// UI::Button::Component.build_classes, in the colors the browser renders
export const buttonClasses = ({ color = 'secondary', size = 'md', htmlClass }) =>
  [BASE_CLASSES, htmlClass, FOCUS_CLASSES, DISABLED_CLASSES, SIZES[size], 'tw:no-underline', COLORS[color], ACTIVE_COLORS[color]].filter(Boolean).join(' ')

// UI::Button::Component. `attributes` is its html_options
export const button = ({ color, size, htmlClass, attributes: htmlOptions = {}, content }) =>
  html`<button ${attributes(htmlOptions)} type="button" class=${buttonClasses({ color, size, htmlClass })}>${content}</button>`
