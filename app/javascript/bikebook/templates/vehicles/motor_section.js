import { copyableCode } from 'bikebook/templates/ui/copyable_code'
import { section } from 'bikebook/templates/vehicles/section'
import { html } from 'lit-html'
import { array, blank, compact, except, join, presence, present, slice } from 'bikebook/templates/values'

// A motor's specs, with a subsection per operating mode
export const motorSection = ({ presenter, heading, motor, others }) => {
  const { fields, humanized, labels } = presenter.kit.motor
  // the identity rows list every mode's classification
  const modeFields = except(presenter.kit.motor.mode_fields, ['e_vehicle_classifications'])
  const display = (each) => ({
    ...each,
    name: [each.manufacturer, each.model].filter(present).join(' '),
    id: each.id ? copyableCode({ value: each.id, label: 'Copy ID' }) : null,
    // `{}` stands in for a motor a compared vehicle doesn't have
    certification: presence(each.certification) ?? (present(each) ? html`<span class="tw:text-yellow-800 tw:dark:text-yellow-400">Unknown</span>` : null),
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
    const modeHeading = presenter.highlighted(presenter.humanize(mode.mode), otherModes.some((each) => each == null))
    const modeRows = presenter.rowsFor(modeFields, displayMode(mode), { labels, others: otherModes.map((each) => each ? displayMode(each) : null) })
    return [modeHeading, presenter.measurementRows(modeRows)]
  })
  return section({ heading, content: presenter.measurementRows(rows), subsections: modes })
}
