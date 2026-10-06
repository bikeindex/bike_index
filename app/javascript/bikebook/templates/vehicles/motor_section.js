import { copyableCode } from 'bikebook/templates/ui/copyable_code'
import { section } from 'bikebook/templates/vehicles/section'
import { array, blank, compact, join, present, slice } from 'bikebook/templates/values'

// to_sentence(two_words_connector: " or ", last_word_connector: " or ")
const sentence = (words) => words.length < 2 ? join(words) : join([join(words.slice(0, -1), ', '), words.at(-1)], ' or ')

// A motor's specs, with a subsection per operating mode
export const motorSection = ({ presenter, heading, motor, others, tooltipped }) => {
  const { fields, mode_fields: modeFields, humanized, labels, classification_tooltips: classificationTooltips } = presenter.kit.motor
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
  // tooltipped after the diff, which a tooltip's random id would always mark
  const rows = presenter.rowsFor(fields, display(motor), { labels, others: others.map(display) })
    .map(([label, value, ...rest]) => [label, rest.at(-1) === 'e_vehicle_classifications' ? sentence(array(value).map((name) => tooltipped(name, classificationTooltips))) : value, ...rest])
  const modes = array(motor.operating_modes).map((mode) => {
    const otherModes = others.map((other) => array(other.operating_modes).find((each) => each.mode === mode.mode))
    const modeHeading = presenter.diffLabel(presenter.humanize(mode.mode), otherModes.some((each) => each == null))
    const modeRows = presenter.rowsFor(modeFields, displayMode(mode), { labels, others: otherModes.map((each) => each ? displayMode(each) : null) })
    return [modeHeading, presenter.measurementRows(modeRows)]
  })
  return section({ heading, content: presenter.measurementRows(rows), subsections: modes })
}
