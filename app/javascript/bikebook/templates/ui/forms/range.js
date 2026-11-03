import { html, nothing } from 'lit-html'
import { attributes } from 'bikebook/templates/attributes'

const INPUT_CLASSES = 'tw:w-full tw:accent-[#715eb2]'

// UI::Forms::Range::Component. `attributes` is its html_options, less a class; a data-action runs beside its own
export const range = ({ name, label, value, max, min = 0, step = 1, minLabel, maxLabel, attributes: { 'data-action': action, ...htmlOptions } = {} }) => {
  const id = htmlOptions.id ?? name
  return html`<div data-controller="ui--forms--range"><label class="tw:flex tw:justify-between tw:text-sm" for=${id}><span>${label}</span><output
    for=${id} class="tw:text-gray-500 tw:tabular-nums tw:dark:text-gray-400" data-ui--forms--range-target="output">${value}</output></label><input
    type="range" name=${name} min=${min} max=${max} step=${step} value=${value} ${attributes({ ...htmlOptions, id })} class=${INPUT_CLASSES}
    data-action=${['input->ui--forms--range#update', action].filter(Boolean).join(' ')}>${minLabel || maxLabel
      ? html`<div class="tw:-mt-2 tw:flex tw:justify-between tw:gap-2 tw:text-xs tw:text-gray-500 tw:dark:text-gray-400"><span>${minLabel}</span><span class="tw:text-right">${maxLabel}</span></div>`
      : nothing}</div>`
}
