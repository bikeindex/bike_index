import { html, nothing } from 'lit-html'
import { amountDisplay } from 'bikebook/templates/helpers'
import { table } from 'bikebook/templates/ui/table'
import { seriesBorder } from 'bikebook/templates/vehicles/geometry_overlay'
import { brakesAt, tireWidth, tireWidthDifference, wheelsAt } from 'bikebook/templates/vehicles/model_viewer'
import { array, isNumber, join, present, slice } from 'bikebook/templates/values'

const latest = (years) => years.reduce((found, year) => found && found.year > year.year ? found : year, null)
const priced = (vehicle) => latest(array(vehicle.years).filter((year) => isNumber(year.original_msrp)))
const currency = (vehicle) => priced(vehicle)?.original_msrp_currency ?? 'USD'
const highest = (values) => values.some(isNumber) ? Math.max(...values.filter(isNumber)) : null
const motors = (key) => (vehicle) => highest(array(vehicle.motors).map((motor) => motor[key]))
const modes = (key) => (vehicle) => highest(array(vehicle.motors).flatMap((motor) => array(motor.operating_modes)).map((mode) => mode[key]))
// A position's teeth, and how many: drivetrain's "12_rear", else as many as are listed, which rear can't say when it
// lists only its smallest and largest cog
const gearing = (position) => (vehicle) => {
  const teeth = array(vehicle.gearing?.[position])
  const speeds = array(vehicle.drivetrain).map((each) => String(each).match(new RegExp(`^(\\d+)[ _]${position}$`, 'i'))?.[1]).find(Boolean)
  if (teeth.length === 0 && !speeds) return null
  return { teeth, count: speeds ? Number(speeds) : position === 'rear' && teeth.length === 2 ? null : teeth.length }
}
// Gearing as [key, number, content] parts, each with a number compared with the first vehicle's part of the same key:
// the cogs' count, then each chainring, or the smallest and largest cog. Keyed from both ends, so a single chainring
// compares with the largest
const gearingParts = (cogs) => (presenter, { count, teeth }) => {
  const shown = cogs ? [...new Set([teeth[0], teeth.at(-1)])] : teeth
  return [
    ...(count == null ? [] : [['count', cogs ? count : null, shown.length ? `${count}:` : String(count)]]),
    ...shown.map((tooth, index) => {
      const last = index === shown.length - 1
      const key = last ? 'largest' : index === 0 ? 'smallest' : `chainring_${index}`
      return [key, tooth, join([presenter.measurement(tooth, last ? 'teeth' : null), last ? '' : cogs ? '–' : ','])]
    })
  ]
}

const GEOMETRY = ['reach', 'stack', 'top_tube_effective', 'head_angle', 'seat_angle', 'chainstay', 'wheelbase', 'standover']

// `better` is the sign of a difference that's an improvement: a lower price, a longer range. 0 for one that's
// neither, and none for a value that isn't compared. `parts` splits a value whose parts are each compared, and
// `amount` shows a difference, given the number it's of
const SPECS = [
  { label: 'Year', read: (vehicle) => latest(array(vehicle.years))?.year, better: 1, format: String },
  {
    label: 'Price',
    read: (vehicle) => priced(vehicle)?.original_msrp,
    better: -1,
    format: (cents, vehicle, presenter) => amountDisplay(cents, currency(vehicle), presenter.vocabulary.currencies),
    comparable: (vehicle, first) => currency(vehicle) === currency(first)
  },
  { label: 'Vehicle type', read: (vehicle) => vehicle.type },
  { label: 'Frame material', read: (vehicle) => vehicle.frame?.material },
  { label: 'Rated power', read: motors('rated_power'), better: 1, unit: 'w' },
  { label: 'Peak power', read: motors('peak_power'), better: 1, unit: 'w' },
  { label: 'Torque', read: motors('max_torque'), better: 1, unit: 'nm' },
  { label: 'Battery', read: motors('battery_size'), better: 1, unit: 'wh' },
  { label: 'Range', read: modes('range_claimed'), better: 1, unit: 'km' },
  { label: 'Top speed', read: modes('max_speed'), better: 1, unit: 'km/h' },
  { label: 'Front travel', read: (vehicle, size) => size?.geometry?.travel_front ?? vehicle.suspension?.front_travel, better: 1, unit: 'mm' },
  { label: 'Rear travel', read: (vehicle, size) => size?.geometry?.travel_rear ?? vehicle.suspension?.rear_travel, better: 1, unit: 'mm' }
]
// the size's, so it closes the geometry
const WEIGHT = { label: 'Weight', read: (vehicle, size) => size?.geometry?.total_weight, better: -1, unit: 'kg' }
const GEARING = [
  { label: 'Chainrings', read: gearing('front'), better: 1, parts: gearingParts(false) },
  { label: 'Cogs', read: gearing('rear'), better: 1, parts: gearingParts(true) }
]

// The compared models' headline specs side by side in their `sizes`, each column's numbers against the first's
export const comparisonTable = ({ presenter, vehicles, sizes, frames = [] }) => {
  const named = vehicles.map(({ data }) => presenter.named(presenter.kit.schemas.vehicle, data))
  const [first] = named
  const show = (row, value, vehicle) => row.format?.(value, vehicle, presenter) ?? (row.unit ? presenter.measurement(value, row.unit, row.key) : value)
  const geometry = GEOMETRY.map((key) => {
    const unit = presenter.kit.schemas.geometry[key]?.unit
    return {
      label: presenter.kit.geometry.labels[key] ?? presenter.humanize(key),
      read: (vehicle, size) => size?.geometry?.[key],
      better: 1,
      unit,
      key,
      amount: (change) => presenter.measurement(change, unit, key, { difference: true })
    }
  })
  const missing = html`<span class="twless-strong">—</span>`
  const wheels = new Map(named.map((vehicle, index) => [vehicle, wheelsAt(presenter, vehicles[index].data, sizes[index])]))
  const tireDifference = (change, width) => tireWidthDifference(presenter, change, width)
  const wheelRows = ['front', 'rear'].flatMap((position) => [
    {
      label: `${presenter.humanize(position)} wheel`,
      read: (vehicle) => wheels.get(vehicle)[position].parts,
      better: 0,
      parts: (_, parts) => parts.map(([key, number, content], index) => [key, number, index < parts.length - 1 ? join([content, ',']) : content]),
      amount: tireDifference
    },
    {
      label: `${presenter.humanize(position)} max tire`,
      read: (vehicle) => wheels.get(vehicle)[position].maxTire,
      better: 1,
      format: (width) => tireWidth(presenter, width),
      amount: tireDifference
    }
  ])
  const brakes = new Map(named.map((vehicle, index) => [vehicle, brakesAt(presenter, vehicles[index].data, sizes[index])]))
  const brakeRows = [{ label: 'Brakes', read: (vehicle) => brakes.get(vehicle).types }, { label: 'Brake rotors', read: (vehicle) => brakes.get(vehicle).rotors }]

  const changed = (row, number, base, fallback) => {
    if (!isNumber(number) || !isNumber(base)) return nothing
    const change = presenter.rounded(number - base)
    if (change === 0) return html`<span class="tw:block tw:text-xs tw:text-gray-400 tw:dark:text-gray-500">-</span>`
    const color = row.better === 0
      ? 'tw:text-gray-500 tw:dark:text-gray-400'
      : Math.sign(change) === row.better ? 'tw:text-green-700 tw:dark:text-green-400' : 'tw:text-red-700 tw:dark:text-red-400'
    // a currency symbol, which carries its name as a title, stays gray like a unit
    return html`<span class="tw:block tw:text-xs ${color} tw:[&_span[title]]:text-gray-400 tw:dark:[&_span[title]]:text-gray-500">${
      change > 0 ? '+' : '−'}${row.amount?.(Math.abs(change), number) ?? fallback(Math.abs(change))}</span>`
  }
  const compared = (row, vehicle) => vehicle !== first && row.better !== undefined && (row.comparable?.(vehicle, first) ?? true)

  const difference = (row, value, base, vehicle) => compared(row, vehicle) ? changed(row, value, base, (amount) => show(row, amount, vehicle)) : nothing

  const partsCell = (row, value, baseParts, vehicle) => {
    const comparing = compared(row, vehicle)
    return html`<span class="tw:inline-flex tw:items-start tw:gap-x-1">${row.parts(presenter, value).map(([key, number, content]) =>
      html`<span>${content}${comparing ? changed(row, number, baseParts.get(key), String) : nothing}</span>`)}</span>`
  }

  const sizeCell = (index) => {
    const { data, value } = vehicles[index]
    const options = array(data.sizes)
    if (options.length < 2) return options[0]?.name ?? missing
    return html`<select class="twinput tw:w-auto tw:py-1 tw:text-sm" aria-label=${`Size of ${named[index].model}`} data-action="bikebook--page#pickSize"
      data-bikebook--page-vehicle-param=${value} data-bikebook--page-first-param=${index === 0}>${options.map((size) =>
        html`<option value=${size.name} ?selected=${size === sizes[index]} data-size=${JSON.stringify({ name: size.name, geometry: slice(size.geometry, ['top_tube_effective', 'reach']) })}>${size.name}</option>`)}</select>`
  }

  const records = (rows) => rows.map((row) => [row, named.map((vehicle, index) => row.read(vehicle, sizes[index]))])
    .filter(([, values]) => values.some(present)).map(([row, values]) => {
      const baseParts = new Map(row.parts && present(values[0]) ? row.parts(presenter, values[0]) : [])
      return {
        label: row.label,
        cell: (index) => {
          if (!present(values[index])) return missing
          return row.parts
            ? partsCell(row, values[index], baseParts, named[index])
            : html`${show(row, values[index], named[index])}${difference(row, values[index], values[0], named[index])}`
        }
      }
    })
  const geometryRecords = records([...geometry, WEIGHT])
  const geometryHeading = { label: html`<span class="tw:block tw:pt-3 tw:text-xs tw:tracking-wider tw:text-[#715eb2] tw:uppercase">Geometry</span>`, cell: () => nothing }
  const rows = [
    ...(sizes.some(Boolean) ? [{ label: 'Size', cell: sizeCell }] : []),
    ...records([...SPECS, ...wheelRows, ...brakeRows, ...GEARING]),
    ...(geometryRecords.length ? [geometryHeading, ...geometryRecords] : [])
  ]

  // Out to the window's edges, the table at least the page's 78rem column and wider as its vehicles need, scrolling
  // only once it's the window's width; its own min-w-full would make it the window's width
  return html`<section aria-label="Comparison" class="tw:mt-6 tw:mx-[calc(50%-50vw)] tw:w-screen tw:px-4">${table({
    classes: 'tw:mx-auto tw:min-w-[min(100%,78rem)]!',
    records: rows,
    columns: [
      { label: html`<span class="tw:sr-only">Spec</span>`, rowHeader: true, classes: 'tw:font-bold tw:whitespace-nowrap tw:align-top', cell: (record) => record.label },
      ...named.map((vehicle, index) => {
        const border = seriesBorder(frames[index], index)
        return {
          label: html`<span class="tw:block tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${vehicle.manufacturer}</span>${vehicle.model}`,
          classes: 'tw:min-w-48 tw:align-top',
          // a model's name can wrap in its header, but not a value
          cellClass: (record) => `tw:whitespace-nowrap ${record === rows.at(-1) ? border : ''}`,
          cell: (record) => record.cell(index)
        }
      })
    ]
  })}</section>`
}
