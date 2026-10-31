import { html, nothing } from 'lit-html'
import { chosenColorway, colorwayValue, colorwayYears } from 'bikebook/colorways'
import { amountDisplay, missing } from 'bikebook/templates/helpers'
import { buttonClasses } from 'bikebook/templates/ui/button'
import { collapse } from 'bikebook/templates/ui/collapse'
import { radioButtonGroup } from 'bikebook/templates/ui/forms/radio_button_group'
import { table } from 'bikebook/templates/ui/table'
import { PINNED_ROW_HEADER } from 'bikebook/templates/vehicles/comparison_table'
import { removeLink } from 'bikebook/templates/vehicles/remove_link'
import { basicsOf, simpleFormat } from 'bikebook/templates/vehicles/model_viewer'
import { colorway, colorways } from 'bikebook/templates/vehicles/model_years'
import { vehicleTitle } from 'bikebook/templates/vehicles/vehicle_title'
import { array, isNumber, join, present } from 'bikebook/templates/values'

// `only` ones once a shown model is electric, suspended, a cargo vehicle or sold outside the visitor's market, the rest once one lists it, and `differing`
// ones where the models' values of it differ
const FIELDS = [
  { label: 'Markets', key: 'markets', only: 'outside_market' },
  { label: 'Model group', key: 'model_group' },
  { label: 'Years', key: 'years' },
  { label: 'Colorway', key: 'colors' },
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

// years come newest first
const priced = (vehicle) => array(vehicle.years).find((year) => isNumber(year.original_msrp))

// the newest year's page still on the manufacturer's site, rather than an archived one
const manufacturerPage = (vehicle) => {
  const url = array(vehicle.years).find((year) => year.url_live && present(year.url))?.url
  return url && html`<small class="tw:text-gray-500 tw:dark:text-gray-400"><a class="twlink-underlined" href=${url}>manufacturer's page</a></small>`
}

// the newest colorways, to choose between where there are several, the `picked` one chosen, and each earlier year's behind
// a link that shows them
// A year's colorways by their paint, not their photos
const paint = (year) => JSON.stringify(array(year.colorways).map(({ name, colors, color_code: code }) => [name, colors, code]))

const colors = (presenter, vehicle, key, picked) => {
  const [newest, ...rest] = colorwayYears(vehicle)
  if (!newest) return null

  const latest = array(newest.colorways)
  const chosen = chosenColorway(vehicle, picked)
  // the toggle's track wrapping its segments, which it doesn't for its own few short ones
  const shown = latest.length > 1
    ? html`<div class="tw:*:flex-wrap">${radioButtonGroup({
      name: `colorway-${key}`,
      entries: latest.map((each, index) => ({ value: colorwayValue(each, index), label: colorway(presenter, each) })),
      selected: colorwayValue(chosen, latest.indexOf(chosen)),
      attributes: { 'data-action': 'change->bikebook--page#pickColorway', 'data-bikebook--page-vehicle-param': key }
    })}</div>`
    : colorways(presenter, latest)
  const earlier = rest.filter((year) => paint(year) !== paint(newest))
  if (earlier.length === 0) return shown

  return html`<div class="tw:space-y-2" data-controller="ui--collapse">${shown}<div class="tw:hidden tw:space-y-1" data-ui--collapse-target="content">${
    earlier.map(({ year, colorways: each }) => html`<div class="tw:flex tw:items-baseline tw:gap-2"><span class="tw:text-xs tw:font-bold tw:tabular-nums">${year}</span>${
      colorways(presenter, array(each))}</div>`)}</div><div>${collapse({ color: 'link_gray', htmlClass: 'tw:text-sm tw:aria-expanded:hidden', content: 'View previous years colors' })}</div></div>`
}

const EXCERPT_LENGTH = 200
const MARKETS_SHOWN = 3

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

// The first MARKETS_SHOWN of `names`, the rest behind a gray link saying how many there are in all, which goes with
// the ellipsis once it shows them
const marketList = (names) => names.length <= MARKETS_SHOWN
  ? names.join(', ')
  : html`<span class="tw:group/markets" data-controller="ui--collapse">${names.slice(0, MARKETS_SHOWN).join(', ')}<span
    class="tw:group-has-[[aria-expanded=true]]/markets:hidden">…</span><span class="tw:hidden"
    data-ui--collapse-target="content">, ${names.slice(MARKETS_SHOWN).join(', ')}</span> ${collapse({
      color: 'link_gray',
      htmlClass: 'tw:text-sm tw:aria-expanded:hidden',
      content: `${names.length} total`
    })}</span>`

// shows the `value`'s group under the overview, or once it's the `shownGroup`, hides it
const viewGroup = (groupPath, value, shownGroup) => html`<a href=${groupPath(value === shownGroup ? '' : value)}
  class=${buttonClasses({ size: 'sm', htmlClass: 'tw:ml-2' })} aria-current=${value === shownGroup ? 'true' : nothing} data-in-place="#model-group">View group</a>`

// The models' names, photos and headline fields side by side in a table, one model's as two's, each photo with an ×
// to the page without it at `removePath`, each column's last cell with its `bottoms` classes, the table's section with
// its `sectionClasses` and its corner with `corner`
export const basics = ({ presenter, vehicles, market, outOfClassId, removePath, colorways: pickedColorways = {}, groupPath, shownGroup, bottoms = [], sectionClasses = '', corner = nothing }) => {
  const shown = vehicles.map(({ data, value, key, outsideMarket }, index) => {
    const price = priced(data)
    const fields = basicsOf({ presenter, data, outOfClassId })
    return {
      ...fields,
      value,
      removeHref: removePath(index),
      model_group: fields.model_group && join([fields.model_group, viewGroup(groupPath, value, shownGroup)], ' '),
      markets: marketList(array(data.markets).map((code) => presenter.vocabulary.names?.markets?.[code] ?? code)),
      outside_market: outsideMarket,
      title: vehicleTitle({ manufacturer: fields.manufacturer, model: fields.model, data, value, market, configurations: presenter.kit.model_configurations }),
      years: join([fields.years, manufacturerPage(data)].filter(present), ' '),
      colors: colors(presenter, data, key, pickedColorways[key]),
      price: price && amountDisplay(price.original_msrp, price.original_msrp_currency, presenter.vocabulary.currencies),
      description: fields.description && readMore(data.description, fields.description)
    }
  })
  const fields = FIELDS.filter((field) => (field.only ? shown.some((each) => each[field.only]) : shown.some((each) => present(each[field.key]))) &&
    (!field.differing || new Set(shown.map((each) => each[field.differing])).size > 1))
  return compared(shown, fields, bottoms, sectionClasses, corner)
}

const compared = (vehicles, fields, bottoms, sectionClasses, corner) => html`<section aria-label=${vehicles.length > 1 ? 'Overview comparison' : 'Overview'} class="tw:mt-6 ${vehicles.length > 3
  ? 'tw:twpagebleed tw:px-4'
  : ''} ${sectionClasses}" style=${`--models: ${vehicles.length}`}>${table({
  classes: `${vehicles.length === 1 ? 'tw:w-full tw:md:w-[calc(50%+6.25rem)] tw:md:min-w-0!' : `tw:w-full ${MIN_WIDTH}`} tw:table-fixed ${vehicles.length > 3 ? `tw:mx-auto ${MAX_WIDTH}` : ''}`,
  records: fields,
  columns: [
    { label: html`<span class="tw:sr-only">Field</span>${corner}`, rowHeader: true, classes: 'tw:w-32 tw:md:w-50 tw:px-2.5! tw:py-2! tw:align-top tw:font-bold', cellClass: () => PINNED_ROW_HEADER, cell: ({ label }) => label },
    ...vehicles.map((vehicle, index) => ({
      label: html`${vehicle.photo('tw:mb-2 tw:aspect-[4/3]')}${removeLink({
        label: `Remove ${[vehicle.manufacturer, vehicle.model].filter(present).join(' ')}`,
        href: vehicle.removeHref,
        corner: true
      })}${vehicle.title}`,
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
