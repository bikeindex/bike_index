import { html } from 'lit-html'
import { table } from 'bikebook/templates/ui/table'
import { array, equal } from 'bikebook/templates/values'

const sameKey = (a, b) => equal([a.type, a.position], [b.type, b.position])
const sameDetail = (a, b) => sameKey(a, b) && equal(a.type_detail, b.type_detail)
const HEADER_CLASSES = 'tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase'
// Stacked in a narrow .bikebook-components, the type and description each take a line, and the detail and position are muted
const COLUMNS = [
  ['type', null, 'tw:w-[18%] tw:break-words tw:@max-[40rem]/bikebook-components:basis-full tw:@max-[40rem]/bikebook-components:font-bold'],
  ['type_detail', 'Detail', 'tw:w-[15%] tw:@max-[40rem]/bikebook-components:text-gray-500 tw:dark:@max-[40rem]/bikebook-components:text-gray-400'],
  ['position', 'Position', 'tw:w-[12%] tw:@max-[40rem]/bikebook-components:text-gray-500 tw:dark:@max-[40rem]/bikebook-components:text-gray-400'],
  ['manufacturer', 'Manufacturer', 'tw:w-[17%]'],
  ['description', 'Description', 'tw:w-[38%] tw:@max-[40rem]/bikebook-components:basis-full']
]

// Whether every vehicle has the row's component, and the same in every column
export const matchingRow = (row) => row.every((component) => component && COLUMNS.every(([field]) => equal(component[field], row[0][field])))

// Each vehicle's `components` (a list per vehicle) as rows of a cell per vehicle, pairing those of the same type and
// position, the same detail first, so a vehicle's repeated component fills a row each
export const pairedComponents = (components) => components.reduce((rows, list, index) => {
  const place = (from, unplaced, matches) => unplaced.reduce(({ rows, rest }, component) => {
    const at = rows.findIndex((row) => !row[index] && matches(row.find(Boolean), component))
    return at < 0 ? { rows, rest: [...rest, component] } : { rows: rows.with(at, rows[at].with(index, component)), rest }
  }, { rows: from, rest: [] })
  const exact = place(rows, array(list), sameDetail)
  const keyed = place(exact.rows, exact.rest, sameKey)
  return [...keyed.rows, ...keyed.rest.map((component) => Array.from(components, (_, at) => at === index ? component : undefined))]
}, [])

// One group's rows as a table, marking each cell where a row's `counterparts` differ, and every cell of a row one
// lacks. A row without a `component` is blank, standing in for one only a compared vehicle has
export const componentGroup = ({ presenter, name, rows, alignKey }) => html`<div class="bikebook-components">${table({
  alignKey,
  records: rows.map(({ component, counterparts }) => component
    ? {
        ...component,
        position: presenter.positionLabel(component.position),
        differs: (field) => counterparts.some((other) => !other || !equal(other[field], component[field]))
      }
    : { differs: () => false }),
  classes: 'tw:table-fixed tw:w-full',
  columns: COLUMNS.map(([field, label, classes]) => ({
    label: label ?? name, classes, headerClasses: HEADER_CLASSES, cellClass: (record) => record.differs(field) && 'tw:spec-diff', cell: (record) => record[field]
  }))
})}</div>`
