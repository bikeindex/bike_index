import { copyableCode } from 'bikebook/templates/ui/copyable_code'
import { section } from 'bikebook/templates/vehicles/section'
import { array, blank, compact, except, join, presence, present, slice } from 'bikebook/templates/values'

const market = (presenter, id) => {
  const code = String(id ?? '').match(/_([a-z]{2})$/)?.[1]?.toUpperCase()
  return code && presenter.vocabulary.names?.markets?.[code] ? code : null
}

// A motor's specs, with a subsection per operating mode, but its certification, which the electric summary beside it
// badges
export const motorSection = ({ presenter, heading, motor, others }) => {
  const { humanized } = presenter.kit.motor
  const fields = except(presenter.kit.motor.fields, ['certification'])
  const labels = presenter.kit.motor.labels
  // the identity rows list every mode's classification
  const modeFields = except(presenter.kit.motor.mode_fields, ['e_vehicle_classifications'])
  const display = (each) => ({
    ...each,
    // a unit linked by its market's id, …_us, named for that market
    name: compact([presence([each.manufacturer, each.model].filter(present).join(' ')), market(presenter, each.id)]).join(', '),
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
  const rows = presenter.rowsFor(fields, display(motor), { labels, others: others.map(display) })
  const modes = array(motor.operating_modes).map((mode) => {
    const otherModes = others.map((other) => array(other.operating_modes).find((each) => each.mode === mode.mode))
    // a mode the others lack is all difference, so its heading is what's marked
    const modeHeading = presenter.highlighted(presenter.modeLabel(mode.mode), otherModes.some((each) => each == null))
    const modeRows = presenter.rowsFor(modeFields, displayMode(mode), { labels, others: otherModes.map((each) => each ? displayMode(each) : null) })
    // one that lists nothing else, as a stock throttle can, says it's stock rather than going unheaded, though a
    // compared model's gives it rows of its own blanks
    return [modeHeading, presenter.measurementRows(modeRows.some(([, value]) => present(value)) ? modeRows : [['Availability', 'Stock']])]
  })
  return section({ heading, content: presenter.measurementRows(rows), subsections: modes })
}
