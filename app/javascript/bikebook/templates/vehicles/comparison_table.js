import { html, nothing } from 'lit-html'
import { amountDisplay } from 'bikebook/templates/helpers'
import { array, present } from 'bikebook/templates/values'

const CELL = 'tw:border-b tw:border-gray-100 tw:px-3 tw:py-2 tw:align-top tw:dark:border-gray-700'

const isNumber = (value) => typeof value === 'number'
const latest = (years) => years.reduce((found, year) => found && found.year > year.year ? found : year, null)
const priced = (vehicle) => latest(array(vehicle.years).filter((year) => isNumber(year.original_msrp)))
const currency = (vehicle) => priced(vehicle)?.original_msrp_currency ?? 'USD'
const highest = (values) => values.some(isNumber) ? Math.max(...values.filter(isNumber)) : null
const motors = (key) => (vehicle) => highest(array(vehicle.motors).map((motor) => motor[key]))
const modes = (key) => (vehicle) => highest(array(vehicle.motors).flatMap((motor) => array(motor.operating_modes)).map((mode) => mode[key]))

// `better` is the sign of a difference that's an improvement: a lower price, a longer range
const ROWS = [
  { label: 'Year', read: (vehicle) => latest(array(vehicle.years))?.year, better: 1, format: String },
  {
    label: 'Price',
    read: (vehicle) => priced(vehicle)?.original_msrp,
    better: -1,
    format: (cents, vehicle, presenter) => amountDisplay(cents, currency(vehicle), presenter.vocabulary.currencies),
    comparable: (vehicle, first) => currency(vehicle) === currency(first)
  },
  { label: 'Weight', read: (vehicle, size) => size?.geometry?.total_weight, better: -1, unit: 'kg' },
  { label: 'Rated power', read: motors('rated_power'), better: 1, unit: 'w' },
  { label: 'Peak power', read: motors('peak_power'), better: 1, unit: 'w' },
  { label: 'Torque', read: motors('max_torque'), better: 1, unit: 'nm' },
  { label: 'Battery', read: motors('battery_size'), better: 1, unit: 'wh' },
  { label: 'Range', read: modes('range_claimed'), better: 1, unit: 'km' },
  { label: 'Top speed', read: modes('max_speed'), better: 1, unit: 'km/h' },
  { label: 'Front travel', read: (vehicle, size) => size?.geometry?.travel_front ?? vehicle.suspension?.front_travel, better: 1, unit: 'mm' },
  { label: 'Rear travel', read: (vehicle, size) => size?.geometry?.travel_rear ?? vehicle.suspension?.rear_travel, better: 1, unit: 'mm' },
  { label: 'Vehicle type', read: (vehicle) => vehicle.type },
  { label: 'Frame material', read: (vehicle) => vehicle.frame?.material }
]

// The compared models' headline specs side by side in their `sizes`, each column's numbers against the first's
export const comparisonTable = ({ presenter, vehicles, sizes }) => {
  const named = vehicles.map(({ data }) => presenter.named(presenter.kit.schemas.vehicle, data))
  const [first] = named
  const show = (row, value, vehicle) => row.format?.(value, vehicle, presenter) ?? (row.unit ? presenter.measurement(value, row.unit) : value)
  const header = (label) => html`<th scope="row" class="${CELL} tw:font-medium tw:whitespace-nowrap tw:text-gray-600 tw:dark:text-gray-400">${label}</th>`

  const difference = (row, value, base, vehicle) => {
    if (vehicle === first || !row.better || !isNumber(value) || !isNumber(base) || !(row.comparable?.(vehicle, first) ?? true)) return nothing

    const change = presenter.rounded(value - base)
    if (change === 0) return html`<span class="tw:block tw:text-xs tw:text-gray-400 tw:dark:text-gray-500">-</span>`
    const color = Math.sign(change) === row.better ? 'tw:text-green-700 tw:dark:text-green-400' : 'tw:text-red-700 tw:dark:text-red-400'
    return html`<span class="tw:block tw:text-xs ${color}">${change > 0 ? '+' : '−'}${show(row, Math.abs(change), vehicle)}</span>`
  }

  // a select where there's a size to pick, and the page renders again from each pick
  const sizeCell = ({ data, value }, index) => {
    const options = array(data.sizes)
    if (options.length < 2) return options[0]?.name ?? html`<span class="twless-strong">—</span>`
    return html`<select class="twinput tw:w-auto tw:py-1 tw:text-sm" aria-label=${`Size of ${named[index].model}`} data-action="bikebook--page#pickSize"
      data-bikebook--page-vehicle-param=${value} data-bikebook--page-first-param=${index === 0}>${options.map((size) =>
        html`<option value=${size.name} ?selected=${size === sizes[index]}>${size.name}</option>`)}</select>`
  }
  const sizeRow = sizes.some(Boolean)
    ? html`<tr class="tw:even:bg-gray-50 tw:dark:even:bg-gray-800/50">${header('Size')}${vehicles.map((vehicle, index) => html`<td class=${CELL}>${sizeCell(vehicle, index)}</td>`)}</tr>`
    : nothing

  const rows = ROWS.map((row) => [row, named.map((vehicle, index) => row.read(vehicle, sizes[index]))])
    .filter(([, values]) => values.some(present)).map(([row, values]) => html`<tr class="tw:even:bg-gray-50 tw:dark:even:bg-gray-800/50">${header(row.label)}${
      named.map((vehicle, index) => html`<td class=${CELL}>${present(values[index]) ? show(row, values[index], vehicle) : html`<span class="twless-strong">—</span>`}${
        difference(row, values[index], values[0], vehicle)}</td>`)}</tr>`)

  return html`<section aria-label="Comparison" class="tw:mx-auto tw:mt-6 tw:max-w-4xl tw:overflow-x-auto tw:rounded-lg tw:border tw:border-gray-200 tw:dark:border-gray-700"><table
    class="tw:w-full tw:border-collapse tw:text-left tw:text-sm"><thead><tr><td class=${CELL}></td>${named.map((vehicle) => html`<th scope="col" class="${CELL} tw:min-w-36"><span
    class="tw:block tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${vehicle.manufacturer}</span>${vehicle.model}</th>`)}</tr></thead><tbody>${sizeRow}${rows}</tbody></table></section>`
}
