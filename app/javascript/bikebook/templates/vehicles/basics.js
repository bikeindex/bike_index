import { html, nothing } from 'lit-html'
import { amountDisplay, missing } from 'bikebook/templates/helpers'
import { table } from 'bikebook/templates/ui/table'
import { priced } from 'bikebook/templates/vehicles/comparison_table'
import { basicsOf, simpleFormat } from 'bikebook/templates/vehicles/model_viewer'
import { CERTIFICATION_LABEL } from 'bikebook/templates/vehicles/motor_section'
import { present } from 'bikebook/templates/values'

// `only` ones once a shown model is electric, suspended or a cargo vehicle, `differing` ones where the models' values of it differ
const FIELDS = [
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
  { label: CERTIFICATION_LABEL, key: 'certification', only: 'electric' },
  { label: 'Description', key: 'description' }
]
// the label column's 12.5rem and 12rem per model, so a phone scrolls the table rather than squeezing it
const MIN_WIDTHS = ['', '', 'tw:min-w-[36.5rem]!', 'tw:min-w-[48.5rem]!', 'tw:min-w-[60.5rem]!', 'tw:min-w-[72.5rem]!']
// past three models, out of the page's column toward the window's edges, each model's column up to 500px
const MAX_WIDTHS = { 4: 'tw:max-w-[calc(12.5rem+2000px)]', 5: 'tw:max-w-[calc(12.5rem+2500px)]' }

const manufacturerLine = (manufacturer) => present(manufacturer)
  ? html`<p class="tw:text-[11px] tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p>`
  : nothing

const EXCERPT_LENGTH = 200

// `text`'s first 200 characters, cut at a word and keeping its paragraphs, with a button for the whole of it as `content`
const readMore = (text, content) => {
  const raw = String(text).replace(/\r\n?/g, '\n').trim()
  if (raw.length <= EXCERPT_LENGTH) return content

  // the next character too, so a cut landing on a word's end keeps the word
  const words = raw.slice(0, EXCERPT_LENGTH + 1).replace(/\s+\S*$/, '').slice(0, EXCERPT_LENGTH)
  const excerpt = `${words.replace(/[\s,.;:—–-]+$/, '')}…`
  return html`<div class="tw:group/read-more" data-controller="bikebook--read-more"><div class="tw:space-y-2 tw:group-data-expanded/read-more:hidden">${
    simpleFormat(excerpt)}</div><div
    class="tw:hidden tw:group-data-expanded/read-more:block">${content}</div><button type="button" aria-expanded="false" class="twlink tw:mt-1 tw:text-sm"
    data-bikebook--read-more-target="button" data-action="bikebook--read-more#toggle"><span class="tw:group-data-expanded/read-more:hidden">Read more</span><span
    class="tw:hidden tw:group-data-expanded/read-more:inline">Show less</span></button></div>`
}

// The models' names, photos and headline fields: one beside its photo, more side by side in a table
export const basics = ({ presenter, vehicles }) => {
  const shown = vehicles.map(({ data }) => {
    const price = priced(data)
    const fields = basicsOf({ presenter, data })
    return {
      ...fields,
      price: price && amountDisplay(price.original_msrp, price.original_msrp_currency, presenter.vocabulary.currencies),
      description: fields.description && readMore(data.description, fields.description)
    }
  })
  const fields = FIELDS.filter((field) => (!field.only || shown.some((each) => each[field.only])) &&
    (!field.differing || new Set(shown.map((each) => each[field.differing])).size > 1))
  return shown.length === 1 ? single(shown[0], fields) : compared(shown, fields)
}

const single = (vehicle, fields) => html`<section aria-label="Overview" class="tw:mt-6 tw:grid tw:items-start tw:gap-8
  tw:md:grid-cols-[minmax(0,1fr)_400px]"><div>${manufacturerLine(vehicle.manufacturer)}<h2 class="tw:font-header tw:text-2xl tw:font-bold">${vehicle.model}</h2><dl
  class="tw:mt-3 tw:text-sm">${fields.filter(({ key }) => present(vehicle[key])).map(({ label, key }) => key === 'description'
    ? html`<div class="tw:py-1.5"><dt class="tw:text-gray-600 tw:dark:text-gray-400">${label}</dt><dd class="tw:mt-1 tw:text-gray-600
      tw:dark:text-gray-400">${vehicle[key]}</dd></div>`
    : html`<div class="tw:flex tw:items-baseline tw:justify-between tw:gap-4 tw:border-b tw:border-gray-100 tw:py-1.5 tw:dark:border-gray-700"><dt
      class="tw:text-gray-600 tw:dark:text-gray-400">${label}</dt><dd class="tw:mb-0 tw:text-right">${vehicle[key]}</dd></div>`)}</dl></div><div
  class="tw:max-md:order-first">${vehicle.photo('tw:aspect-[4/3]')}</div></section>`

const compared = (vehicles, fields) => html`<section aria-label="Overview comparison" class="tw:mt-6 ${vehicles.length > 3
  ? 'tw:mx-[calc(50%-50vw)] tw:w-screen tw:px-4'
  : ''}">${table({
  classes: `tw:w-full tw:table-fixed ${MIN_WIDTHS[vehicles.length] ?? MIN_WIDTHS.at(-1)} ${vehicles.length > 3 ? `tw:mx-auto ${MAX_WIDTHS[vehicles.length] ?? MAX_WIDTHS[5]}` : ''}`,
  records: fields,
  columns: [
    { label: html`<span class="tw:sr-only">Field</span>`, rowHeader: true, classes: 'tw:w-50 tw:px-2.5! tw:py-2! tw:align-top tw:font-bold', cell: ({ label }) => label },
    ...vehicles.map((vehicle) => ({
      label: html`${vehicle.photo('tw:mb-2 tw:aspect-[4/3]')}${manufacturerLine(vehicle.manufacturer)}${vehicle.model}`,
      classes: 'tw:px-2.5! tw:py-2! tw:align-top',
      cellClass: ({ key }) => key === 'description' ? 'tw:text-sm' : '',
      cell: ({ key, only }) => {
        if (present(vehicle[key])) return vehicle[key]
        if (only !== 'electric' || vehicle.electric) return missing
        return key === 'e_vehicle_class' ? html`<span class="twless-strong tw:italic">not e-vehicle</span>` : nothing
      }
    }))
  ]
})}</section>`
