import { copyableId } from 'bikebook/templates/copyable_id'
import { section } from 'bikebook/templates/vehicles/section'
import { array, blank, compact, join, present, slice } from 'bikebook/templates/values'

// to_sentence(two_words_connector: " or ", last_word_connector: " or ")
const sentence = (words) => words.length < 2 ? words.join('') : `${words.slice(0, -1).join(', ')} or ${words.at(-1)}`

// A motor's specs, with a subsection per operating mode
export const motorSection = ({ presenter, heading, motor, others }) => {
  const { fields, mode_fields: modeFields, humanized, labels } = presenter.kit.motor
  const display = (each) => ({
    ...each,
    name: [each.manufacturer, each.model].filter(present).join(' '),
    id: each.id ? copyableId({ id: each.id }) : null,
    us_e_bike_class: each.us_e_bike_class == null ? null : `Class ${sentence(each.us_e_bike_class)}`,
    ...Object.fromEntries(Object.entries(slice(each, humanized)).map(([key, value]) => [key, value == null ? value : presenter.humanize(value)]))
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
    const modeHeading = presenter.diffLabel(presenter.humanize(mode.mode), otherModes.some((each) => each == null))
    const modeRows = presenter.rowsFor(modeFields, displayMode(mode), { labels, others: otherModes.map((each) => each ? displayMode(each) : null) })
    return [modeHeading, presenter.measurementRows(modeRows)]
  })
  return section({ heading, content: presenter.measurementRows(rows), subsections: modes })
}
