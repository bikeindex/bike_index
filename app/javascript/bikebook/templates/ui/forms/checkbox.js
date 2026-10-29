import { html, nothing } from 'lit-html'
import { attributes } from 'bikebook/templates/attributes'

const INPUT_CLASSES = 'tw:h-4 tw:w-4 tw:shrink-0 tw:mt-[calc((1lh_-_1rem)/2)] tw:cursor-pointer tw:disabled:cursor-not-allowed'

// UI::Forms::Checkbox::Component with a bare `name`. `attributes` is its html_options, less a class
export const checkbox = ({ name, label, checked = false, value = '1', className, attributes: htmlOptions = {} }) => html`<label
  class=${['twlabel tw:flex tw:cursor-pointer tw:items-start tw:gap-2 tw:has-disabled:cursor-not-allowed', className].filter(Boolean).join(' ')}><input
  type="checkbox" name=${name} value=${value} ${attributes({ id: name, ...htmlOptions })} class=${INPUT_CLASSES} checked=${checked ? 'checked' : nothing}><span>${label}</span></label>`
