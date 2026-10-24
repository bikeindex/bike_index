import { html, nothing } from 'lit-html'
import { amountDisplay, missing } from 'bikebook/templates/helpers'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { collapse } from 'bikebook/templates/ui/collapse'
import { copyButton } from 'bikebook/templates/ui/copy_button'
import { table } from 'bikebook/templates/ui/table'
import { PINNED_ROW_HEADER } from 'bikebook/templates/vehicles/comparison_table'
import { marketNote } from 'bikebook/templates/vehicles/market_note'
import { removeLink } from 'bikebook/templates/vehicles/remove_link'
import { basicsOf, simpleFormat } from 'bikebook/templates/vehicles/model_viewer'
import { array, isNumber, join, present } from 'bikebook/templates/values'

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
  { label: 'Wheel & tire size', key: 'wheel_size' },
  { label: 'Suspension front/rear', key: 'suspension', only: 'suspended' },
  { label: 'Groupset', key: 'groupset' },
  { label: 'Price', key: 'price' },
  { label: 'E-vehicle class', key: 'e_vehicle_class', only: 'electric' },
  { label: 'Electric Certification', key: 'certification', only: 'electric' },
  { label: 'Description', key: 'description' }
]
// the label column's 12.5rem and 12rem per one of the section's --models, so a phone scrolls the table rather than
// squeezing it. One model's column is as wide as each of two's, the label's 12.5rem and half what's left
const MIN_WIDTH = 'tw:min-w-[calc(12.5rem+12rem*var(--models))]!'
// past three models, out of the page's column toward the window's edges, each model's column up to 500px
const MAX_WIDTH = 'tw:max-w-[calc(12.5rem+500px*var(--models))]'

const manufacturerLine = (manufacturer) => present(manufacturer)
  ? html`<p class="tw:text-[11px] tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${manufacturer}</p>`
  : nothing

// years come newest first
const priced = (vehicle) => array(vehicle.years).find((year) => isNumber(year.original_msrp))

// the newest year's page still on the manufacturer's site, rather than an archived one
const manufacturerPage = (vehicle) => {
  const url = array(vehicle.years).find((year) => year.url_live && present(year.url))?.url
  return url && html`<small class="tw:text-gray-500 tw:dark:text-gray-400"><a class="twlink-underlined" href=${url}>manufacturer's page</a></small>`
}

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

// shows the `value`'s group under the overview, or once it's the `shownGroup`, hides it
const viewGroup = (groupPath, value, shownGroup) => html`<a href=${groupPath(value === shownGroup ? '' : value)}
  class=${buttonClasses({ size: 'sm', htmlClass: 'tw:ml-2' })} aria-current=${value === shownGroup ? 'true' : nothing} data-in-place="#model-group">View group</a>`

// The models' names, photos and headline fields side by side in a table, one model's as two's, each photo with an ×
// to the page without it at `removePath`, each column's last cell with its `bottoms` classes and the table's section with
// its `sectionClasses`
export const basics = ({ presenter, vehicles, market, outOfClassId, removePath, groupPath, shownGroup, bottoms = [], sectionClasses = '' }) => {
  const shown = vehicles.map(({ data, value, outsideMarket }, index) => {
    const price = priced(data)
    const fields = basicsOf({ presenter, data, outOfClassId })
    return {
      ...fields,
      value,
      removeHref: removePath(index),
      model_group: fields.model_group && join([fields.model_group, viewGroup(groupPath, value, shownGroup)], ' '),
      markets: array(data.markets).map((code) => presenter.vocabulary.names?.markets?.[code] ?? code).join(', '),
      outside_market: outsideMarket,
      market_note: marketNote({ markets: array(data.markets), market, names: presenter.vocabulary.names?.markets }),
      years: join([fields.years, manufacturerPage(data)].filter(present), ' '),
      price: price && amountDisplay(price.original_msrp, price.original_msrp_currency, presenter.vocabulary.currencies),
      description: fields.description && readMore(data.description, fields.description)
    }
  })
  const fields = FIELDS.filter((field) => (field.only ? shown.some((each) => each[field.only]) : shown.some((each) => present(each[field.key]))) &&
    (!field.differing || new Set(shown.map((each) => each[field.differing])).size > 1))
  return compared(shown, fields, bottoms, sectionClasses)
}

const compared = (vehicles, fields, bottoms, sectionClasses) => html`<section aria-label=${vehicles.length > 1 ? 'Overview comparison' : 'Overview'} class="tw:mt-6 ${vehicles.length > 3
  ? 'tw:twpagebleed tw:px-4'
  : ''} ${sectionClasses}" style=${`--models: ${vehicles.length}`}>${table({
  classes: `${vehicles.length === 1 ? 'tw:w-full tw:md:w-[calc(50%+6.25rem)] tw:md:min-w-0!' : `tw:w-full ${MIN_WIDTH}`} tw:table-fixed ${vehicles.length > 3 ? `tw:mx-auto ${MAX_WIDTH}` : ''}`,
  records: fields,
  columns: [
    { label: html`<span class="tw:sr-only">Field</span>`, rowHeader: true, classes: 'tw:w-32 tw:md:w-50 tw:px-2.5! tw:py-2! tw:align-top tw:font-bold', cellClass: () => PINNED_ROW_HEADER, cell: ({ label }) => label },
    ...vehicles.map((vehicle, index) => ({
      label: html`${vehicle.photo('tw:mb-2 tw:aspect-[4/3]')}${removeLink({
        label: `Remove ${[vehicle.manufacturer, vehicle.model].filter(present).join(' ')}`,
        href: vehicle.removeHref,
        corner: true
      })}${manufacturerLine(vehicle.manufacturer)}<span class="tw:inline-flex tw:items-baseline tw:gap-1">${
        vehicle.model}${vehicle.market_note}${copyButton({ value: vehicle.value, label: 'Copy ID', tooltip: true })}</span>`,
      classes: 'tw:px-2.5! tw:py-2! tw:align-top',
      headerClasses: 'tw:relative',
      cellClass: ({ key }) => [key === 'description' && 'tw:text-sm', key === fields.at(-1).key && bottoms[index]].filter(Boolean).join(' '),
      cell: ({ key, only }) => {
        if (present(vehicle[key])) return vehicle[key]
        if (only !== 'electric' || vehicle.electric) return missing
        return key === 'e_vehicle_class' ? html`<span class="twless-strong">not e-vehicle</span>` : nothing
      }
    }))
  ]
})}</section>`
