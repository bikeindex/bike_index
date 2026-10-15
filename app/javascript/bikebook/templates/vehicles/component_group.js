import { table } from 'bikebook/templates/ui/table'
import { array, equal } from 'bikebook/templates/values'

export const componentKey = (component) => [component.type, component.type_detail, component.position]
const HEADER_CLASSES = 'tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase'
const COLUMNS = [
  ['type', null, 'tw:w-[18%] tw:break-words'],
  ['type_detail', 'Detail', 'tw:w-[15%]'],
  ['position', 'Position', 'tw:w-[12%]'],
  ['manufacturer', 'Manufacturer', 'tw:w-[17%]'],
  ['description', 'Description', 'tw:w-[38%]']
]

// One group's components as a table, marking each cell where the same component in `others` differs, and every
// cell of one they lack. A blank `components` entry is an empty row, standing in for one a compared vehicle has
export const componentGroup = ({ presenter, name, components, others, alignKey }) => table({
  alignKey,
  records: components.map((component) => {
    if (!component) return { differs: () => false }
    const counterparts = others.map((otherComponents) => array(otherComponents).find((other) => equal(componentKey(other), componentKey(component))))
    return {
      ...component,
      position: presenter.positionLabel(component.position),
      differs: (field) => counterparts.some((other) => !other || !equal(other[field], component[field]))
    }
  }),
  classes: 'tw:table-fixed tw:w-full tw:min-w-[44rem]!',
  columns: COLUMNS.map(([field, label, classes]) => ({
    label: label ?? name, classes, headerClasses: HEADER_CLASSES, cellClass: (record) => record.differs(field) && 'tw:spec-diff', cell: (record) => record[field]
  }))
})
