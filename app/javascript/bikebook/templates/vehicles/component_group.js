import { table } from 'bikebook/templates/ui/table'
import { array, equal } from 'bikebook/templates/values'

const key = (component) => [component.type, component.type_detail, component.position]

// One group's components as a table, marking a component `others` lack or differ on
export const componentGroup = ({ presenter, name, components, others }) => table({
  records: components.map((component) => ({
    ...component,
    position: presenter.positionLabel(component.position),
    differs: others.some((otherComponents) => !equal(array(otherComponents).find((other) => equal(key(other), key(component))), component))
  })),
  classes: 'tw:table-fixed tw:w-full tw:min-w-[44rem]!',
  columns: [
    { label: name, classes: 'tw:w-[18%] tw:break-words', headerClasses: 'tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase', cellClass: (record) => record.differs && 'tw:spec-diff', cell: (record) => record.type },
    { label: 'Detail', classes: 'tw:w-[15%]', headerClasses: 'tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase', cell: (record) => record.type_detail },
    { label: 'Position', classes: 'tw:w-[12%]', headerClasses: 'tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase', cell: (record) => record.position },
    { label: 'Manufacturer', classes: 'tw:w-[17%]', headerClasses: 'tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase', cell: (record) => record.manufacturer },
    { label: 'Description', classes: 'tw:w-[38%]', headerClasses: 'tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase', cell: (record) => record.description }
  ]
})
