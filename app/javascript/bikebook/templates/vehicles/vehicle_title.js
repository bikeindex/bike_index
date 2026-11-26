import { html, nothing } from 'lit-html'
import { inlineBadge } from 'bikebook/templates/ui/badge'
import { copyButton } from 'bikebook/templates/ui/copy_button'
import { configurationNote } from 'bikebook/templates/vehicles/configuration_note'
import { marketNote } from 'bikebook/templates/vehicles/market_note'
import { array, present } from 'bikebook/templates/values'

const HEADING = 'tw:inline tw:font-extrabold'

const viewJson = (id) => html` <small class="tw:whitespace-nowrap tw:text-gray-500 tw:dark:text-gray-400">or <a class="twlink-underlined"
  href=${`/bikebook_schemas/${id}`}>view JSON</a></small>`

export const manufacturerLine = (manufacturer) => present(manufacturer)
  ? html`<p class="tw:tweyebrow tw:mb-1">${manufacturer}</p>`
  : nothing

// A compared vehicle's model, after an e-vehicle's badge, its configuration where it isn't complete by the kit's
// `configurations` names, the markets selling it where `market` doesn't and the copy button for its id, `value`, its
// tooltip linking the JSON, inline after its last line. As an 'h3' `heading`, set large
const modelLine = ({ model, data, value, market, configurations, heading }) => {
  const size = heading ? 'md' : 'sm'
  const name = html`${model}${configurationNote({ configuration: data.model_configuration, names: configurations, size })}${
    marketNote({ markets: array(data.markets), market })}`
  return html`<div class=${heading ? 'tw:text-2xl tw:leading-tight' : ''}>${present(data.motors)
    ? html`${inlineBadge({ text: '⚡', title: 'E-vehicle', color: 'purple', size })} `
    : nothing}${heading ? html`<h3 class=${HEADING}>${name}</h3>` : name} <span
    class="tw:inline-block tw:align-middle">${copyButton({ value, label: 'Copy ID', tooltip: true, after: viewJson(value) })}</span></div>`
}

// Its manufacturer over its modelLine, as each view heads a compared vehicle
export const vehicleTitle = (args) => html`${manufacturerLine(args.manufacturer)}${modelLine(args)}`
