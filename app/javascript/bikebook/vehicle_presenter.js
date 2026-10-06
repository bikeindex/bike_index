import { html, nothing } from 'lit-html'
import { numberDisplay } from 'bikebook/templates/helpers'
import { definitionListRow } from 'bikebook/templates/ui/definition_list/row'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { array, blank, compact, equal, isHash, isTemplate, join } from 'bikebook/templates/values'

const roundHalfUp = (value) => Math.sign(value) * Math.round(Math.abs(value))

const CLASSIFICATIONS = 'motors.e_vehicle_classifications'

// The names, units and lookups the vehicle templates present a model's data with
export class VehiclePresenter {
  constructor (kit, vocabulary) {
    this.kit = kit
    // `names` leaves off a classification's jurisdiction: "Moped", where it's "US-CA Moped"
    const classifications = Object.entries(vocabulary.e_vehicle_classifications ?? {})
    const names = Object.fromEntries(classifications.map(([id, { jurisdiction, name }]) => [id, `${jurisdiction} ${name}`]))
    this.vocabulary = { ...vocabulary, names: { ...vocabulary.names, [CLASSIFICATIONS]: { ...vocabulary.names[CLASSIFICATIONS], ...names } } }
    this.classificationTooltips = Object.fromEntries(classifications.map(([id, record]) => [names[id], this.#classificationTooltip(names[id], record)]))
    this.half = new RegExp(kit.shis.half)
    this.shisPattern = new RegExp(kit.shis.pattern)
    this.imperialLengths = kit.imperial_lengths.map(({ pattern, parts }) => ({ pattern: new RegExp(pattern), parts }))
    this.unitSuffix = new RegExp(kit.geometry.unit_suffix)
    this.componentGroups = new Map(Object.entries(kit.component_groups).flatMap(([group, types]) => types.map((type) => [type, group])))
  }

  // `hash` with each slug the vocabulary names as its name
  named (definition, hash, path = '') {
    return Object.fromEntries(Object.entries(hash).map(([key, value]) => {
      const field = definition?.[key]
      const fieldPath = path ? `${path}.${key}` : key
      const names = this.vocabulary.names[fieldPath]
      if (!field) return [key, value]
      if (field.fields && isHash(value)) return [key, this.named(field.fields, value, fieldPath)]
      if (field.each && Array.isArray(value)) return [key, value.map((item) => this.named(field.each, item, fieldPath))]
      if (names) return [key, Array.isArray(value) ? value.map((item) => names[item] ?? item) : names[value] ?? value]
      return [key, value]
    }))
  }

  // the US jurisdiction's classifications are the three e-bike classes
  #classificationTooltip (name, { jurisdiction, description, restrictions }) {
    return html`<h3 class="tw:font-bold">${name}${jurisdiction === 'US' ? ' e-bike' : ''}</h3><p class="tw:my-1">${description}</p><ul
      class="tw:list-disc tw:pl-4">${array(restrictions).map((restriction) => html`<li>${restriction}</li>`)}</ul>`
  }

  measurement (value, unit = null, key = null) {
    if (value === true) return '✓'
    if (value === false) return '❌'
    if (Array.isArray(value)) return join(value, ', ')
    const [, count, each] = (unit && typeof value === 'string' && value.match(/^(\d+) x (\d+(?:\.\d+)?)$/)) || []
    if (each) return join([`${count} × `, this.measurement(this.rounded(parseFloat(each)), unit, key)])
    if (typeof value !== 'number') return isTemplate(value) ? value : String(value ?? '')

    const parts = this.#imperialParts(unit, key)
    const feet = parts.length === 2
    const metric = feet ? this.labeled(this.rounded(value / this.kit.conversions.mm.cm), 'cm', this.kit.presenter.centimeters) : this.labeled(value, unit)
    if (parts.length === 0) return metric

    const imperial = join(parts.map(({ part, convert }) => this.labeled(this.rounded(convert(value)), unit, part)), ' ')
    // rounded to the inch, so the metric value is a hover away
    return this.#unitSystems(metric, feet ? this.#tooltipped(imperial, [metric]) : imperial)
  }

  // all three read "136.5 × 66.6 × 137 cm" (L × W × H); fewer name each, "136.5 cm long"
  dimensions (dimensions) {
    const { cm } = this.kit.conversions.mm
    const words = Object.keys(this.kit.presenter.dimension_words)
    const values = words.filter((key) => dimensions[key] != null).map((key) => [key, dimensions[key]])
    const full = values.length === words.length
    const metric = values.map(([key, mm], index) => [key, this.labeled(this.rounded(mm / cm), full && index < values.length - 1 ? null : 'cm', this.kit.presenter.centimeters)])
    const feetAndInches = this.#feetAndInches()
    // leading parts that come to zero are left out: no "0'" before a length under a foot
    const imperial = values.map(([key, mm]) => {
      const first = feetAndInches.findIndex(({ convert }) => convert(mm) !== 0)
      return [key, join((first < 0 ? [] : feetAndInches.slice(first)).map(({ part, convert }) => this.labeled(convert(mm), 'mm', part)), ' ')]
    })
    const exact = [(mm) => this.labeled(this.rounded(mm), 'mm'), (mm) => this.labeled(this.rounded(this.#inches(mm)), 'mm', this.kit.inches)]
    const [metricSystem, imperialSystem] = [metric, imperial].map((parts, index) => this.#tooltipped(
      full ? join(parts.map(([, part]) => part), ' × ') : join(parts.map(([key, part]) => join([part, ' ', this.kit.presenter.dimension_words[key]])), ', '),
      values.map(([key, mm]) => join([`${this.humanize(key)}: `, exact[index](mm)]))
    ))
    return this.#unitSystems(metricSystem, imperialSystem)
  }

  #unitSystems (metric, imperial) {
    return join([html`<span class="tw:imperial:hidden">${metric}</span>`, html`<span class="tw:hidden tw:imperial:inline">${imperial}</span>`])
  }

  #tooltipped (content, lines) {
    return tooltip({ content, body: join(lines.map((line) => html`<span class="tw:block">${line}</span>`)) })
  }

  measurementRows (rows) {
    return join(rows.map(([label, value, unit, differs, key]) => definitionListRow({ label: this.diffLabel(label, differs), content: this.measurement(value, unit, key) })))
  }

  diffLabel (label, differs) {
    return differs ? html`<span class="tw:spec-diff">${label}</span>` : label
  }

  positionLabel (position) {
    const positions = array(position)
    return positions.length ? positions.map((part) => this.humanize(part)).join(' & ') : null
  }

  rowsFor (definition, source, { labels = {}, others = [], collapse = [] } = {}) {
    const values = isHash(source) ? source : {}
    const otherSources = others.map((other) => isHash(other) ? other : {})
    return Object.entries(definition).flatMap(([key, meta]) => {
      const value = values[key]
      const otherValues = otherSources.map((other) => other[key])
      if (blank(value) && otherValues.every(blank)) return []

      const label = labels[key] ?? this.humanize(key)
      if (meta.fields && !collapse.includes(key) && [value, ...otherValues].some(isHash)) {
        return this.rowsFor(meta.fields, value, { others: otherValues }).map(([rowLabel, ...row]) => [`${label} ${String(rowLabel).toLowerCase()}`, ...row])
      }
      return [[label, value, meta.unit, otherValues.some((other) => !equal(other, value)), key]]
    })
  }

  labeled (value, unit, meta = this.kit.units[unit] ?? {}) {
    const number = html`<span class="tw:font-mono">${numberDisplay(value)}</span>`
    if (blank(unit)) return number
    // a thin space, so the unit reads as part of the value
    const gap = ['°', "'", '"'].includes(meta.label) ? '' : ' '
    return join([number, gap, html`<span class="tw:text-xs tw:text-gray-400 tw:dark:text-gray-500" title=${meta.name ?? nothing}>${meta.label ?? unit}</span>`])
  }

  #inches (millimeters) {
    return millimeters / this.kit.conversions.mm.in
  }

  // Whole feet, then the inches left over
  #feetAndInches () {
    const inches = (length) => roundHalfUp(this.#inches(length))
    return this.kit.feet_and_inches.map((part, index) => ({ part, convert: index === 0 ? (length) => Math.floor(inches(length) / 12) : (length) => inches(length) % 12 }))
  }

  #imperialParts (unit, key) {
    const { mm, g } = this.kit.conversions
    const inches = (millimeters) => this.#inches(millimeters)
    const miles = (kilometers) => kilometers * mm.km / mm.mi
    const units = { km: miles, 'km/h': miles, kg: (kilograms) => kilograms * g.kg / g.lb, c: (celsius) => celsius * 1.8 + 32 }
    if (unit !== 'mm') return this.kit.imperial_units[unit] ? [{ part: this.kit.imperial_units[unit], convert: units[unit] }] : []

    const parts = this.imperialLengths.find(({ pattern }) => pattern.test(String(key ?? '')))?.parts ?? []
    return parts.length === 2 ? this.#feetAndInches() : parts.map((part) => ({ part, convert: inches }))
  }

  rounded (value) {
    return roundHalfUp(value * 10) / 10
  }

  humanize (text) {
    const words = String(text).replace(/^_+/, '').replace(/_id$/, '').replaceAll('_', ' ')
      .replace(/[a-z\d]+/gi, (word) => this.kit.acronyms[word.toLowerCase()] ?? word.toLowerCase())
    return words.replace(/^\w/, (character) => character.toUpperCase())
  }

  // A SHIS headset code's steering column and cups, in words
  shisLabel (code) {
    if (typeof code !== 'string' || !this.shisPattern.test(code)) return null
    const parsed = code.split('|').map((part) => this.#shisHalf(part.trim()))
    const halves = parsed.filter(Boolean)
    const [top] = parsed
    const cups = [...new Set(halves.map(({ cup }) => cup))]
    const column = top && this.kit.shis.steering_columns.find(([diameter, pitch]) => diameter === top.diameter && (pitch ?? null) === (top.thread_pitch ?? null))
    return compact([column?.[2], cups.length === 1 ? cups[0] : `${cups[0]} top, ${cups.at(-1)} bottom`]).join(', ')
  }

  #shisHalf (text) {
    const groups = text.match(this.half)?.groups
    if (!groups) return null
    return Object.fromEntries(Object.entries(groups).filter(([, value]) => value != null)
      .map(([key, value]) => [key, key === 'cup' ? this.kit.shis.cups[value] : parseFloat(value)]))
  }
}
