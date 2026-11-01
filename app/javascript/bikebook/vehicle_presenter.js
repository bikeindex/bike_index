import { html, nothing } from 'lit-html'
import { fragmentOf } from 'bikebook/render'
import { numberDisplay } from 'bikebook/templates/helpers'
import { copyableCode } from 'bikebook/templates/atoms/copyable_code'
import { colorSwatch } from 'bikebook/templates/ui/color_swatch'
import { definitionListRow } from 'bikebook/templates/ui/definition_list/row'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { array, blank, compact, equal, isHash, isTemplate, join, listed } from 'bikebook/templates/values'

const roundHalfUp = (value) => Math.sign(value) * Math.round(Math.abs(value))

// What content reads as, which a template's random tooltip ids don't change
const textOf = (content) => (typeof content === 'object' ? fragmentOf(content).textContent : String(content ?? '')).replace(/\s+/g, ' ').trim()
// A list's items, through the lists inside it
const items = (content) => listed(content)?.[0].flatMap(items) ?? [content]
const mark = (content) => html`<span class="tw:spec-diff">${content}</span>`

const MATERIALS = 'frame.material'
const TOP_TUBES = 'frame.top_tube'
// lengths in centimeters, with an imperial viewer's feet and inches after
const IN_CENTIMETERS = ['wheelbase', 'standover', 'standover_above_bb']
const SINGULAR = { feet: 'foot', inches: 'inch' }

// The names, units and lookups the vehicle templates present a model's data with
// read as part of their number, unmuted
const FEET_AND_INCHES = ["'", '"']

export class VehiclePresenter {
  constructor (kit, vocabulary) {
    // the extras' bb_drop_low as the catalog's own labels write "BB Drop", and standover above it short, as its tooltip
    // explains it
    this.kit = {
      ...kit,
      acronyms: { ...kit.acronyms, bb: 'BB' },
      geometry: { ...kit.geometry, labels: { ...kit.geometry.labels, standover_above_bb: 'Standover above BB' } }
    }
    // the catalog names carbon "Carbon or Composite", and leaves its top tubes and target riders unnamed
    const materials = { ...vocabulary.names[MATERIALS], carbon: 'Carbon/Composite' }
    const topTubes = { step_through: 'Step-through', sloping: 'Sloping', horizontal: 'Horizontal', ...vocabulary.names[TOP_TUBES] }
    const riders = { kid: 'Kids', woman: "Women's", adaptive: 'Adaptive', ...vocabulary.names.target_riders }
    this.vocabulary = { ...vocabulary, names: { ...vocabulary.names, [MATERIALS]: materials, [TOP_TUBES]: topTubes, target_riders: riders } }
    this.half = new RegExp(kit.shis.half)
    this.shisPattern = new RegExp(kit.shis.pattern)
    // standover above the bottom bracket in feet and inches, as a wheelbase is, where the kit's standover reads in inches
    this.imperialLengths = [{ pattern: /^standover_above_bb$/, parts: kit.feet_and_inches },
      ...kit.imperial_lengths.map(({ pattern, parts }) => ({ pattern: new RegExp(pattern), parts }))]
    this.unitSuffix = new RegExp(kit.geometry.unit_suffix)
    this.componentGroups = new Map(Object.entries(kit.component_groups).flatMap(([group, types]) => types.map((type) => [type, group])))
  }

  // A colorway's color by its name, a slug or the vocabulary's name for one, beside Bike Index's swatch of it
  paintColor (color) {
    return join(compact([this.#paintName(color), this.paintSwatch(color)]), ' ')
  }

  // Bike Index's swatch of a colorway's color, null for one it has none of
  paintSwatch (color) {
    const name = this.#paintName(color)
    const [paint, display] = Object.entries(this.vocabulary.paint_colors ?? {}).find(([each]) => each.toLowerCase() === name.toLowerCase()) ?? []
    return paint ? colorSwatch({ name: paint, display, size: 'sm', align: 'baseline' }) : null
  }

  #paintName (color) {
    return this.vocabulary.names['years.colorways.colors']?.[color] ?? color
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

  classificationName (id) {
    return this.vocabulary.e_vehicle_classifications[id]?.label ?? id
  }

  // its description less the IDs it cites, beside the ID it shows
  classificationTooltip (id) {
    const { title, description } = this.vocabulary.e_vehicle_classifications[id]
    return html`<h3 class="tw:font-bold">${title}</h3><span class="tw:mt-1 tw:flex tw:items-center tw:gap-2">ID ${
      copyableCode({ value: id, label: 'Copy ID' })}</span><p class="tw:mt-1">${String(description ?? '').replace(/\s*\(evc\/[^)\s]+\)/g, '')}</p>`
  }

  // Each classification's name to its tooltip
  classificationTooltips () {
    return Object.fromEntries(Object.entries(this.vocabulary.e_vehicle_classifications)
      .map(([id, { label }]) => [label, this.classificationTooltip(id)]))
  }

  // A `difference` of a length in centimeters leaves off its feet and inches
  measurement (value, unit = null, key = null, { difference = false } = {}) {
    if (value === true) return '✓'
    if (value === false) return '❌'
    if (Array.isArray(value)) return join(value.map((item) => this.measurement(item, unit, key)), ', ')
    const [, count, each] = (unit && typeof value === 'string' && value.match(/^(\d+) x (\d+(?:\.\d+)?)$/)) || []
    if (each) return join([`${count} × `, this.measurement(this.rounded(parseFloat(each)), unit, key, { difference })])
    if (typeof value !== 'number') return isTemplate(value) ? value : String(value ?? '')

    const parts = this.#imperialParts(unit, key)
    const feet = parts.length === 2
    const inCentimeters = IN_CENTIMETERS.includes(key)
    const metric = feet || inCentimeters
      ? this.labeled(this.rounded(value / this.kit.conversions.mm.cm), 'cm', this.kit.presenter.centimeters)
      : this.labeled(value, unit)
    if (parts.length === 0 || (inCentimeters && difference)) return metric

    const imperial = join((feet ? this.#significant(parts, value) : parts).map(({ part, convert }) => this.labeled(this.rounded(convert(value)), unit, part)), ' ')
    // rounded to the inch, so the exact length is a hover away
    const shown = feet ? this.#tooltipped(imperial, compact([this.#inWords(value), inCentimeters ? null : metric])) : imperial
    // muted by its color, as an opacity would fade the tooltip inside it too
    return this.#unitSystems(metric, inCentimeters ? join([metric, ' ', html`<span class="tw:text-xs tw:text-gray-500 tw:dark:text-gray-400">(${shown})</span>`]) : shown)
  }

  // In feet and inches, or centimeters in metric: "6' 4"", "194 cm"
  length (millimeters) {
    return this.#unitSystems(this.#centimeters(millimeters),
      join(this.#feetAndInches().map(({ part, convert }) => this.labeled(this.rounded(convert(millimeters)), 'mm', part)), ' '))
  }

  // Spelled out, the other system's after: "6 feet, 4 inches (194 cm)", "194 cm (6 feet, 4 inches)"
  lengthInWords (millimeters) {
    const [centimeters, words] = [this.#centimeters(millimeters), this.#inWords(millimeters)]
    return this.#unitSystems(join([centimeters, ` (${words})`]), join([words, ' (', centimeters, ')']))
  }

  #centimeters (millimeters) {
    return this.labeled(this.rounded(millimeters / this.kit.conversions.mm.cm), 'cm', this.kit.presenter.centimeters)
  }

  // all three read "136.5 × 66.6 × 137 cm" (L × W × H); fewer name each, "136.5 cm long"
  dimensions (dimensions) {
    const { cm } = this.kit.conversions.mm
    const words = Object.keys(this.kit.presenter.dimension_words)
    const values = words.filter((key) => dimensions[key] != null).map((key) => [key, dimensions[key]])
    const full = values.length === words.length
    const centimeters = (mm, unit = 'cm') => this.labeled(this.rounded(mm / cm), unit, this.kit.presenter.centimeters)
    const metric = values.map(([key, mm], index) => [key, centimeters(mm, full && index < values.length - 1 ? null : 'cm')])
    const feetAndInches = this.#feetAndInches()
    const imperial = values.map(([key, mm]) => [key, join(this.#significant(feetAndInches, mm).map(({ part, convert }) => this.labeled(convert(mm), 'mm', part)), ' ')])
    const exact = [(mm) => this.labeled(this.rounded(mm), 'mm'), (mm) => join([this.#inWords(mm), ' (', centimeters(mm), ')'])]
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
    return join(rows.map(([label, value, unit, differs, key, others]) => definitionListRow({
      label, content: this.highlighted(this.measurement(value, unit, key), differs, differs && others?.map((other) => this.measurement(other, unit, key)))
    })))
  }

  // Marks `content` where it differs from the compared vehicles' `others`: just the items of a list the others don't
  // all have, else all of it. Left alone when blank, so a row with no value still renders nothing
  highlighted (content, differs, others) {
    if (!differs || blank(content)) return content
    if (!listed(content) || !others || others.some(blank)) return mark(content)

    const theirs = others.map((other) => new Set(items(other).map(textOf)))
    const texts = new Map(items(content).map((item) => [item, textOf(item)]))
    const shared = (item) => theirs.every((each) => each.has(texts.get(item)))
    if (items(content).every(shared)) return mark(content)
    const marked = (value) => {
      const [parts, separator] = listed(value) ?? []
      if (parts) return join(parts.map(marked), separator)
      return shared(value) ? value : mark(value)
    }
    return marked(content)
  }

  positionLabel (position) {
    const positions = array(position)
    return positions.length ? positions.map((part) => this.humanize(part)).join(' & ') : null
  }

  // `display` presents a field's value, as it does the others'
  rowsFor (definition, source, { labels = {}, others = [], collapse = [], display = (value) => value } = {}) {
    const values = isHash(source) ? source : {}
    const otherSources = others.map((other) => isHash(other) ? other : {})
    return Object.entries(definition).flatMap(([key, meta]) => {
      const value = values[key]
      const otherValues = otherSources.map((other) => other[key])
      if (blank(value) && otherValues.every(blank)) return []

      const label = labels[key] ?? this.humanize(key)
      if (meta.fields && !collapse.includes(key) && [value, ...otherValues].some(isHash)) {
        return this.rowsFor(meta.fields, value, { others: otherValues, display }).map(([rowLabel, ...row]) => [`${label} ${String(rowLabel).toLowerCase()}`, ...row])
      }
      return [[label, display(value, key), meta.unit, otherValues.some((other) => !equal(other, value)), key, otherValues.map((other) => display(other, key))]]
    })
  }

  labeled (value, unit, meta = this.kit.units[unit] ?? {}) {
    const number = html`<span class="tw:font-mono">${numberDisplay(value)}</span>`
    if (blank(unit)) return number
    // a thin space, so the unit reads as part of the value
    const gap = ['°', ...FEET_AND_INCHES].includes(meta.label) ? '' : ' '
    const classes = FEET_AND_INCHES.includes(meta.label) ? nothing : 'tw:text-xs tw:text-gray-400 tw:dark:text-gray-500'
    return join([number, gap, html`<span class=${classes} title=${meta.name ?? nothing}>${meta.label ?? unit}</span>`])
  }

  #inches (millimeters) {
    return millimeters / this.kit.conversions.mm.in
  }

  // `parts` from the first that `millimeters` doesn't come to zero in: 9", not 0' 9"
  #significant (parts, millimeters) {
    const first = parts.findIndex(({ convert }) => convert(millimeters) !== 0)
    return first < 0 ? parts.slice(-1) : parts.slice(first)
  }

  // "3 feet, 2.6 inches", leaving off a part that's zero
  #inWords (millimeters) {
    const [feet, inches] = this.#feetAndInches((value) => this.rounded(value)).map(({ part, convert }) => [this.rounded(convert(millimeters)), part.name])
    return [feet, inches].filter(([count], index) => count !== 0 || (index === 1 && !feet[0]))
      .map(([count, name]) => `${count} ${count === 1 ? SINGULAR[name] ?? name : name}`).join(', ')
  }

  // Whole feet, then the inches left over, to the nearest whole inch unless `round` says otherwise
  #feetAndInches (round = roundHalfUp) {
    const inches = (length) => round(this.#inches(length))
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

  // A motor's operating mode, "Pedal assist" rather than the catalog's bare "assist"
  modeLabel (mode) {
    return mode === 'assist' ? 'Pedal assist' : this.humanize(mode)
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
