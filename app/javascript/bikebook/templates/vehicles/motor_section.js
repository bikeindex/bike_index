import { copyableCode } from 'bikebook/templates/atoms/copyable_code'
import { section } from 'bikebook/templates/vehicles/section'
import { array, blank, compact, except, isNumber, join, presence, present, slice } from 'bikebook/templates/values'

const BATTERY_FIELDS = { capacity: {}, capacity_options: {}, charging_time: {}, cells: {}, weight: { unit: 'kg' }, removable: {} }
const BATTERY_LABELS = { capacity_options: 'Options' }

// "4 h 30 min"
const duration = (minutes) => [[Math.floor(minutes / 60), 'h'], [minutes % 60, 'min']].filter(([count]) => count).map((part) => part.join(' ')).join(' ')

// A battery's values as its rows show them: "672 Wh, 48 V Li-ion", "also 500, 625 Wh"
const batteryRows = (presenter, battery = {}) => {
  const { capacity, voltage, chemistry, capacity_options: options, charging_time: chargingTime, removable } = battery
  const volts = join(compact([isNumber(voltage) ? presenter.measurement(voltage, 'v') : null, chemistry ? presenter.humanize(chemistry) : null]), ' ')
  return {
    ...battery,
    capacity: presence(join(compact([isNumber(capacity) ? presenter.measurement(capacity, 'wh') : null, presence(volts)]), ', ')),
    capacity_options: present(options) ? join(['also ', join([...options.slice(0, -1).map((each) => presenter.measurement(each)), presenter.measurement(options.at(-1), 'wh')], ', ')]) : null,
    charging_time: isNumber(chargingTime) ? duration(chargingTime) : null,
    removable: removable == null ? null : removable ? 'Yes' : 'No'
  }
}

const market = (presenter, id) => {
  const code = String(id ?? '').match(/-([a-z]{2})$/)?.[1]?.toUpperCase()
  return code && presenter.vocabulary.names?.markets?.[code] ? code : null
}

// A motor's specs, with a subsection for its battery and one per operating mode, but its certifications, which the
// electric summary beside it badges
export const motorSection = ({ presenter, heading, motor, others }) => {
  const { humanized, labels } = presenter.kit.motor
  const fields = except(presenter.kit.motor.fields, ['certifications', 'battery'])
  // the identity rows list every mode's classification
  const modeFields = except(presenter.kit.motor.mode_fields, ['e_vehicle_classifications'])
  const display = (each) => ({
    ...each,
    // a unit linked by its market's id, …-us, named for that market
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
  const battery = presenter.rowsFor(BATTERY_FIELDS, batteryRows(presenter, motor.battery), {
    labels: BATTERY_LABELS, others: others.map((other) => batteryRows(presenter, other.battery))
  })
  return section({ heading, content: presenter.measurementRows(rows), subsections: [['Battery', presenter.measurementRows(battery)], ...modes] })
}
