import { copyableCode } from 'bikebook/templates/ui/copyable_code'
import { section } from 'bikebook/templates/vehicles/section'
import { array, blank, compact, join, present, slice } from 'bikebook/templates/values'

// A motor's specs, with a subsection per operating mode
export const motorSection = ({ presenter, heading, motor, others, tooltipped, classificationPath }) => {
  const { fields, mode_fields: modeFields, humanized } = presenter.kit.motor
  // the kit's "US e-bike class" doesn't fit a California classification
  const labels = { ...presenter.kit.motor.labels, e_vehicle_classifications: 'Classification' }
  const display = (each) => ({
    ...each,
    name: [each.manufacturer, each.model].filter(present).join(' '),
    id: each.id ? copyableCode({ value: each.id, label: 'Copy ID' }) : null,
    // a merged motor lists each of its drive wheels
    ...Object.fromEntries(Object.entries(slice(each, humanized)).map(([key, value]) => [key, value == null ? value : array(value).map((part) => presenter.humanize(part)).join(', ')]))
  })
  const temperatureRange = (temperature) => blank(temperature)
    ? null
    : join(compact([temperature.min, temperature.max]).map((value) => presenter.measurement(value, 'c')), ' to ')
  const displayMode = (mode) => ({
    ...mode,
    availability: mode.availability === 'stock' || mode.availability == null ? null : presenter.humanize(mode.availability),
    operating_temperature: temperatureRange(mode.operating_temperature)
  })
  const classificationTooltips = presenter.classificationTooltips(classificationPath)
  // tooltipped after the diff, which a tooltip's random id would always mark
  const rows = presenter.rowsFor(fields, display(motor), { labels, others: others.map(display) })
    .map(([label, value, ...rest]) => [label, rest.at(-1) === 'e_vehicle_classifications' ? join(array(value).map((name) => tooltipped(name, classificationTooltips)), ', ') : value, ...rest])
  const modes = array(motor.operating_modes).map((mode) => {
    const otherModes = others.map((other) => array(other.operating_modes).find((each) => each.mode === mode.mode))
    const modeHeading = presenter.diffLabel(presenter.humanize(mode.mode), otherModes.some((each) => each == null))
    const modeRows = presenter.rowsFor(modeFields, displayMode(mode), { labels, others: otherModes.map((each) => each ? displayMode(each) : null) })
    return [modeHeading, presenter.measurementRows(modeRows)]
  })
  return section({ heading, content: presenter.measurementRows(rows), subsections: modes })
}
