import { html, nothing } from 'lit-html'
import { attributes } from 'bikebook/templates/attributes'
import { BASE_CLASSES, DISABLED_CLASSES, FOCUS_CLASSES } from 'bikebook/templates/ui/button'

// UI::ButtonGroup::Component's TRACK_CLASSES and SEGMENT_CLASSES, with UI::Forms::RadioButtonGroup's LABEL_CLASSES
const TRACK_CLASSES = 'tw:inline-flex tw:gap-[3px] tw:rounded-[10px] tw:border tw:border-gray-200 tw:bg-gray-100 tw:p-[3px] tw:dark:border-gray-700 tw:dark:bg-gray-800'
const SEGMENT_CLASSES = `${BASE_CLASSES} ${FOCUS_CLASSES} ${DISABLED_CLASSES} ` +
  'tw:rounded-lg tw:px-3 tw:py-[5px] tw:text-[11.5px]/[1.2] tw:font-extrabold tw:whitespace-nowrap tw:transition-colors tw:no-underline ' +
  'tw:hover:no-underline tw:text-gray-400 tw:not-disabled:not-aria-disabled:hover:text-gray-900 tw:focus:ring-purple-500/40 tw:is-active:bg-white ' +
  'tw:is-active:text-gray-900 tw:is-active:shadow-sm tw:is-active:dark:bg-gray-900 tw:is-active:dark:text-gray-100 tw:mb-0 tw:relative ' +
  'tw:has-[:focus-visible]:outline-none tw:has-[:focus-visible]:ring-3 tw:has-[:focus-visible]:ring-purple-500/40'

// UI::Forms::RadioButtonGroup::Component of the toggle kind. `attributes` is its html_options, on each radio, less a class
export const radioButtonGroup = ({ name, entries, selected, attributes: htmlOptions = {} }) => html`<div class=${TRACK_CLASSES}>${entries.map(({ value, label, disabled }) =>
  html`<label class=${SEGMENT_CLASSES} aria-disabled=${disabled ? 'true' : nothing}><input type="radio" name=${name}
    id=${`${name}_${value}`} value=${value} ${attributes(htmlOptions)} class="tw:sr-only" checked=${value === selected ? 'checked' : nothing}
    disabled=${disabled ? 'disabled' : nothing}><span>${label}</span></label>`)}</div>`
