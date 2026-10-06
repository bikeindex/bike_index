import { copyableCode } from 'bikebook/templates/ui/copyable_code'
import { section } from 'bikebook/templates/vehicles/section'
import { CLASSIFICATIONS } from 'bikebook/vehicle_presenter'
import { array, blank, compact, join, present, slice } from 'bikebook/templates/values'

// to_sentence(two_words_connector: " or ", last_word_connector: " or ")
const sentence = (words) => words.length < 2 ? join(words) : join([join(words.slice(0, -1), ', '), words.at(-1)], ' or ')

// The catalog's db/e_vehicle_classifications descriptions, which it doesn't publish yet
const DEFINITIONS = {
  'ec/us/class_1': 'A pedal-assist electric bicycle: the motor helps only while the rider pedals, and stops helping at 20 mph. Defined by the three-class model law most states have adopted; state and local rules can add to these.',
  'ec/us/class_2': 'A throttle electric bicycle: the motor can propel it without pedaling, and stops helping at 20 mph, by throttle or by pedal assist. Defined by the three-class model law most states have adopted; state and local rules can add to these.',
  'ec/us/class_3': 'A speed pedal-assist electric bicycle: the motor helps only while the rider pedals, and stops helping at 28 mph. Defined by the three-class model law most states have adopted; state and local rules can add to these.',
  'ec/us/ca/moped': 'A moped or motorized bicycle: two or three wheels, a motor under 4 gross brake horsepower (3,000 W), and a top speed of 30 mph on level ground. Defined by California Vehicle Code §406, as amended by SB 1167 (Chapter 846, Statutes of 2026).',
  'ec/us/ca/motor_driven_cycle': 'A light electric motorcycle: its motor produces 5 gross brake horsepower (3,750 W) or less, the electric counterpart of a motorcycle under 150 cc. Defined by California Vehicle Code §405, as amended by SB 1167 (Chapter 846, Statutes of 2026).',
  'ec/us/ca/motorcycle': 'A road-registered electric motorcycle: its motor produces more than 5 gross brake horsepower (3,750 W), above what a motor-driven cycle may. Defined by California Vehicle Code §400, with the line set by SB 1167 (Chapter 846, Statutes of 2026).',
  'ec/us/ca/off_highway_electric_motorcycle': 'An electric motorcycle built for riding off the highway, an "eMoto": two wheels, handlebars, a straddle seat and no pedals from the manufacturer, with no limit on power or speed. Defined by California Vehicle Code §436.1, added by SB 586 (2025).'
}

// A motor's specs, with a subsection per operating mode
export const motorSection = ({ presenter, heading, motor, others, withTooltip }) => {
  const { fields, mode_fields: modeFields, humanized } = presenter.kit.motor
  // the kit labels it "US e-bike class", but each value names its own jurisdiction
  const labels = { ...presenter.kit.motor.labels, e_vehicle_classifications: 'Classification' }
  const definitions = Object.fromEntries(Object.entries(presenter.vocabulary.names[CLASSIFICATIONS]).map(([slug, name]) => [name, DEFINITIONS[slug]]))
  const classifications = (names) => sentence(names.map((name) => definitions[name] ? withTooltip(name, definitions[name]) : name))
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
    .map(([label, value, unit, differs, key]) => [label, key === 'e_vehicle_classifications' ? classifications(value) : value, unit, differs, key])
  const modes = array(motor.operating_modes).map((mode) => {
    const otherModes = others.map((other) => array(other.operating_modes).find((each) => each.mode === mode.mode))
    const modeHeading = presenter.diffLabel(presenter.humanize(mode.mode), otherModes.some((each) => each == null))
    const modeRows = presenter.rowsFor(modeFields, displayMode(mode), { labels, others: otherModes.map((each) => each ? displayMode(each) : null) })
    return [modeHeading, presenter.measurementRows(modeRows)]
  })
  return section({ heading, content: presenter.measurementRows(rows), subsections: modes })
}
