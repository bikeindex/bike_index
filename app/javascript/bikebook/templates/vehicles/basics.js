import { html, nothing } from 'lit-html'
import { amountDisplay, missing } from 'bikebook/templates/helpers'
import { collapse } from 'bikebook/templates/ui/collapse'
import { copyButton } from 'bikebook/templates/ui/copy_button'
import { table } from 'bikebook/templates/ui/table'
import { basicsOf, simpleFormat } from 'bikebook/templates/vehicles/model_viewer'
import { array, isNumber, present } from 'bikebook/templates/values'

// `only` ones once a shown model is electric, suspended, a cargo vehicle or sold outside the visitor's market, the rest once one lists it, and `differing`
// ones where the models' values of it differ
const FIELDS = [
  { label: 'Markets', key: 'markets', only: 'outside_market' },
  { label: 'Model group', key: 'model_group' },
  { label: 'Years', key: 'years' },
  { label: 'Vehicle type', key: 'vehicle_type', differing: 'type' },
  { label: 'Cargo', key: 'cargo', only: 'cargo_vehicle' },
  { label: 'Primary activity', key: 'primary_activity' },
  { label: 'Frame material', key: 'frame_material' },
  { label: 'Wheel size', key: 'wheel_size', differing: 'wheel_bsds' },
  { label: 'Suspension front/rear', key: 'suspension', only: 'suspended' },
  { label: 'Groupset', key: 'groupset' },
  { label: 'Price', key: 'price' },
  { label: 'E-vehicle class', key: 'e_vehicle_class', only: 'electric' },
  { label: 'Electric Certification', key: 'certification', only: 'electric' },
  { label: 'Description', key: 'description' }
]
// the label column's 12.5rem and 12rem per model, so a phone scrolls the table rather than squeezing it. One model's
// column is as wide as each of two's, the label's 12.5rem and half what's left
const MIN_WIDTHS = ['', '', 'tw:min-w-[36.5rem]!', 'tw:min-w-[48.5rem]!', 'tw:min-w-[60.5rem]!', 'tw:min-w-[72.5rem]!']
// past three models, out of the page's column toward the window's edges, each model's column up to 500px
const MAX_WIDTHS = { 4: 'tw:max-w-[calc(12.5rem+2000px)]', 5: 'tw:max-w-[calc(12.5rem+2500px)]' }

const manufacturerLine = (manufacturer) => present(manufacturer)
  ? html`<p class="tw:text-[11px] tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p>`
  : nothing

// years come newest first
const priced = (vehicle) => array(vehicle.years).find((year) => isNumber(year.original_msrp))

const EXCERPT_LENGTH = 200

// `text`'s first 200 characters, cut at a word and keeping its paragraphs, which a collapse swaps for the whole of it as
// `content`
const readMore = (text, content) => {
  const raw = String(text).replace(/\r\n?/g, '\n').trim()
  if (raw.length <= EXCERPT_LENGTH) return content

  // the next character too, so a cut landing on a word's end keeps the word
  const words = raw.slice(0, EXCERPT_LENGTH + 1).replace(/\s+\S*$/, '').slice(0, EXCERPT_LENGTH)
  const excerpt = `${words.replace(/[\s,.;:—–-]+$/, '')}…`
  return html`<div class="tw:group/read-more" data-controller="ui--collapse"><div
    class="tw:space-y-2 tw:group-has-[[aria-expanded=true]]/read-more:hidden">${simpleFormat(excerpt)}</div><div class="tw:hidden"
    data-ui--collapse-target="content">${content}</div>${collapse({
      color: 'link',
      chevron: 'trailing',
      htmlClass: 'tw:group/more tw:mt-1 tw:text-sm',
      content: html`<span class="tw:group-aria-expanded/more:hidden">Read more</span><span class="tw:hidden tw:group-aria-expanded/more:inline">Show less</span>`
    })}</div>`
}

// The models' names, photos and headline fields side by side in a table, one model's as two's
export const basics = ({ presenter, vehicles, throttleBarredIn }) => {
  const shown = vehicles.map(({ data, value, outsideMarket }) => {
    const price = priced(data)
    const fields = basicsOf({ presenter, data, throttleBarredIn })
    return {
      ...fields,
      value,
      markets: array(data.markets).map((code) => presenter.vocabulary.names?.markets?.[code] ?? code).join(', '),
      outside_market: outsideMarket,
      price: price && amountDisplay(price.original_msrp, price.original_msrp_currency, presenter.vocabulary.currencies),
      description: fields.description && readMore(data.description, fields.description)
    }
  })
  const fields = FIELDS.filter((field) => (field.only ? shown.some((each) => each[field.only]) : shown.some((each) => present(each[field.key]))) &&
    (!field.differing || new Set(shown.map((each) => each[field.differing])).size > 1))
  return compared(shown, fields)
}

const compared = (vehicles, fields) => html`<section aria-label=${vehicles.length > 1 ? 'Overview comparison' : 'Overview'} class="tw:mt-6 ${vehicles.length > 3
  ? 'tw:mx-[calc(50%-50vw)] tw:w-screen tw:px-4'
  : ''}">${table({
  classes: `${vehicles.length === 1 ? 'tw:w-full tw:md:w-[calc(50%+6.25rem)] tw:md:min-w-0!' : 'tw:w-full'} tw:table-fixed ${MIN_WIDTHS[vehicles.length] ?? MIN_WIDTHS.at(-1)} ${vehicles.length > 3 ? `tw:mx-auto ${MAX_WIDTHS[vehicles.length] ?? MAX_WIDTHS[5]}` : ''}`,
  records: fields,
  columns: [
    { label: html`<span class="tw:sr-only">Field</span>`, rowHeader: true, classes: 'tw:w-50 tw:px-2.5! tw:py-2! tw:align-top tw:font-bold', cell: ({ label }) => label },
    ...vehicles.map((vehicle) => ({
      label: html`${vehicle.photo('tw:mb-2 tw:aspect-[4/3]')}${manufacturerLine(vehicle.manufacturer)}<span class="tw:inline-flex tw:items-baseline tw:gap-1">${
        vehicle.model}${copyButton({ value: vehicle.value, label: 'Copy ID', tooltip: true })}</span>`,
      classes: 'tw:px-2.5! tw:py-2! tw:align-top',
      cellClass: ({ key }) => key === 'description' ? 'tw:text-sm' : '',
      cell: ({ key, only }) => {
        if (present(vehicle[key])) return vehicle[key]
        if (only !== 'electric' || vehicle.electric) return missing
        return key === 'e_vehicle_class' ? html`<span class="twless-strong">not e-vehicle</span>` : nothing
      }
    }))
  ]
})}</section>`
