import { html, nothing } from 'lit-html'
import { OVERALL_LENGTH_ESTIMATE } from 'bikebook/frame_geometry'
import { missing } from 'bikebook/templates/helpers'
import { table } from 'bikebook/templates/ui/table'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { seriesBorders } from 'bikebook/templates/vehicles/geometry_overlay'
import { cargoAt, isCargo, tireWidth, wheelsAt } from 'bikebook/templates/vehicles/model_viewer'
import { array, isNumber, join, present, slice, sum } from 'bikebook/templates/values'

const GEOMETRY = ['reach', 'stack', 'top_tube_effective', 'head_angle', 'seat_angle', 'chainstay', 'standover', 'wheelbase']
// the size's, so it closes the geometry
const WEIGHT = { label: 'Weight', read: (vehicle, size) => size?.geometry?.total_weight, better: -1, unit: 'kg' }

// The compared models' sizes, wheels and frames side by side in their `sizes`, each column's numbers against the
// first's, keyed to the overlay by `frames`. `beside` the overlay, it shares a row with it once the window is wide enough.
// A row's `better` is the sign of a difference that's an improvement, a longer wheelbase, 0 for one that's neither, and
// none for a value that isn't compared. `parts` splits a value whose parts are each compared, and `amount` shows a
// difference, given the number it's of
export const comparisonTable = ({ presenter, vehicles, sizes, frames = [], beside = false }) => {
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
  const wheels = new Map(named.map((vehicle, index) => [vehicle, wheelsAt(presenter, vehicles[index].data, sizes[index])]))
  const length = {
    ...geometry.find(({ key }) => key === 'wheelbase'),
    label: html`Overall length (est.) ${tooltip({ text: `Overall length is ${OVERALL_LENGTH_ESTIMATE}` })}`,
    read: (vehicle) => {
      const listed = frames[named.indexOf(vehicle)]?.wheels
      return listed ? presenter.rounded(sum(Object.values(listed))) : null
    }
  }
  // in mm, though a wide tire reads in inches
  const tireDifference = (change) => presenter.measurement(change, 'mm')
  const wheelRows = ['front', 'rear'].flatMap((position) => [
    {
      label: `${presenter.humanize(position)} wheel`,
      read: (vehicle) => wheels.get(vehicle)[position].parts,
      better: 0,
      parts: (parts) => parts.map(([key, number, content], index) => [key, number, index < parts.length - 1 ? join([content, ',']) : content]),
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

  const changed = (row, number, base, fallback) => {
    if (!isNumber(number) || !isNumber(base)) return nothing
    const change = presenter.rounded(number - base)
    if (change === 0) return html`<span class="tw:block tw:text-xs tw:text-gray-400 tw:dark:text-gray-500">-</span>`
    const color = row.better === 0
      ? 'tw:text-gray-500 tw:dark:text-gray-400'
      : Math.sign(change) === row.better ? 'tw:text-green-700 tw:dark:text-green-400' : 'tw:text-red-700 tw:dark:text-red-400'
    // a currency symbol, which carries its name as a title, stays gray like a unit
    return html`<span class="tw:block tw:text-xs ${color} tw:[&_span[title]]:text-gray-400 tw:dark:[&_span[title]]:text-gray-500">${
      change > 0 ? '+' : '−'}${row.amount?.(Math.abs(change)) ?? fallback(Math.abs(change))}</span>`
  }
  const compared = (row, vehicle) => vehicle !== first && row.better !== undefined

  const difference = (row, value, base, vehicle) => compared(row, vehicle) ? changed(row, value, base, (amount) => show(row, amount, vehicle)) : nothing

  const partsCell = (row, value, baseParts, vehicle) => {
    const comparing = compared(row, vehicle)
    return html`<span class="tw:inline-flex tw:items-start tw:gap-x-1">${row.parts(value).map(([key, number, content]) =>
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
      const baseParts = new Map(row.parts && present(values[0]) ? row.parts(values[0]) : [])
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
  const size = { label: 'Size', cell: sizeCell, className: 'tw:bg-blue-50 tw:dark:bg-blue-950' }
  const sizeRows = sizes.some(Boolean) ? [size] : []
  const cargos = new Map(named.map((vehicle, index) => [vehicle, cargoAt(presenter, vehicles[index].data, sizes[index])]))
  const cargoRows = vehicles.some(({ data }) => isCargo(data)) ? records([{ label: 'Cargo', read: (vehicle) => cargos.get(vehicle) }]) : []
  const rows = [...records(wheelRows), ...cargoRows, ...sizeRows, ...records([...geometry, length, WEIGHT])]
  if (rows.length === 0) return nothing

  // Out to the window's edges, the table at least the page's 78rem column and wider as its vehicles need, scrolling
  // only once it's the window's width; its own min-w-full would make it the window's width
  return html`<section aria-label="Sizes & geometry comparison" class="tw:mt-6 tw:twpagebleed tw:px-4 ${beside ? 'tw:min-[1500px]:mx-0 tw:min-[1500px]:w-auto tw:min-[1500px]:min-w-0 tw:min-[1500px]:flex-1 tw:min-[1500px]:px-0' : ''}">${table({
    classes: 'tw:mx-auto tw:min-w-[min(100%,78rem)]!',
    records: rows,
    columns: [
      { label: html`<span class="tw:sr-only">Spec</span>`, rowHeader: true, classes: 'tw:font-bold tw:whitespace-nowrap tw:align-top', cellClass: (record) => record.className, cell: (record) => record.label },
      ...named.map((vehicle, index) => {
        const border = seriesBorders(frames, index)
        return {
          label: html`<span class="tw:block tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${vehicle.manufacturer}</span>${vehicle.model}`,
          classes: 'tw:min-w-48 tw:align-top',
          headerClasses: border.top,
          // a model's name can wrap in its header, but not a value
          cellClass: (record) => `tw:whitespace-nowrap ${record.className ?? ''}`,
          cell: (record) => record.cell(index)
        }
      })
    ]
  })}</section>`
}
