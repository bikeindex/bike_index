import { html, nothing, render } from 'lit-html'
import { copyableId } from 'bikebook/templates/copyable_id'
import { numberDisplay } from 'bikebook/templates/helpers'
import { x } from 'bikebook/templates/icons'
import { collapse } from 'bikebook/templates/ui/collapse'
import { definitionListContainer } from 'bikebook/templates/ui/definition_list/container'
import { definitionListRow } from 'bikebook/templates/ui/definition_list/row'
import { jsonDisplay } from 'bikebook/templates/ui/json_display'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { componentGroup } from 'bikebook/templates/vehicles/component_group'
import { geometryCard } from 'bikebook/templates/vehicles/geometry_card'
import { modelYears } from 'bikebook/templates/vehicles/model_years'
import { motorSection } from 'bikebook/templates/vehicles/motor_section'
import { section } from 'bikebook/templates/vehicles/section'
import { array, blank, compact, equal, except, join, partsOf, presence, present, slice, sum, truthy } from 'bikebook/templates/values'

// Ruby's \s, which a thin space isn't
const KEEP_TOGETHER = /^([^]*[ \t\r\n\f\v])?([^ \t\r\n\f\v]+)$/
const upcaseFirst = (text) => text.charAt(0).toUpperCase() + text.slice(1)

// One vehicle's card, marked where it differs from `others`
export const modelViewer = (args) => new ModelViewer(args).render()

class ModelViewer {
  constructor ({ presenter, data, value, comparing, idSuffix, others, removePath }) {
    this.presenter = presenter
    this.kit = presenter.kit
    this.data = data
    this.vehicle = this.#normalize(data)
    this.others = others.map((other) => this.#normalize(other))
    Object.assign(this, { value, comparing, idSuffix, removePath })
  }

  render () {
    const { vehicle, comparing, presenter } = this
    const jsonPanelId = `vehicle-model-json-${this.idSuffix}`
    const base = 'tw:flex tw:flex-col tw:gap-6 tw:transition tw:duration-300 tw:lg:flex-row tw:lg:items-stretch'
    const titleText = [vehicle.manufacturer, vehicle.model].filter(present).join(' ')
    const header = html`<header><div class="tw:flex tw:items-start tw:gap-4">${present(vehicle.manufacturer)
      ? html`<p class="tw:mb-1 tw:font-display tw:text-lg tw:font-semibold tw:tracking-wide tw:text-blueprint tw:uppercase">${vehicle.manufacturer}</p>`
      : nothing}<a aria-label=${`Remove ${titleText}`} data-controller="bikebook--remove-vehicle"
      data-action="ui--alert#close bikebook--remove-vehicle#remove"
      data-turbo-prefetch="false" class="tw:-my-1.5 tw:-mr-1.5 tw:ml-auto tw:inline-flex tw:h-8 tw:w-8 tw:shrink-0 tw:items-center tw:justify-center
      tw:rounded-sm tw:text-gray-500 tw:hover:bg-vellum tw:focus:ring-2 tw:focus:ring-gray-400 tw:dark:text-gray-400" href=${this.removePath}>${
        x('tw:h-3 tw:w-3')}</a></div><div class="tw:flex tw:items-baseline tw:justify-between tw:gap-4"><h1
      class="tw:font-display tw:text-2xl tw:leading-tight tw:font-semibold">${vehicle.model}</h1>${collapse({
        size: 'sm',
        htmlClass: 'tw:shrink-0 tw:whitespace-nowrap',
        attributes: { 'aria-controls': jsonPanelId, 'aria-label': 'Toggle JSON' },
        content: html`<code>{ }</code>`
      })}</div></header>`
    const columns = this.specColumns(this.#photo(vehicle.stock_photo, titleText), [
      this.identity(),
      modelYears({ presenter, years: vehicle.years, others: this.others.map((other) => other.years) }),
      this.suspension(),
      section({ heading: 'Frame', content: presenter.measurementRows(this.specRows('frame')) })
    ], [
      ...this.motorSections(),
      section({ heading: 'Cargo', content: presenter.measurementRows(this.specRows('cargo')) }),
      this.wheels(),
      this.positioned('Brakes', 'brakes', 'Brake', (brake) => this.brakeSummary(brake)),
      this.drivetrain()
    ])
    const specs = html`<div class="tw:@container"><div class="tw:flex tw:flex-col tw:@min-[600px]:flex-row tw:@min-[600px]:gap-6">${columns.map((column) =>
      html`<div class="tw:contents tw:@min-[600px]:block tw:@min-[600px]:min-w-0 tw:@min-[600px]:flex-1">${column}</div>`)}</div></div>`
    return html`<div class=${comparing ? `${base} tw:md:min-w-[22rem] tw:md:has-[[aria-controls^=vehicle-model-json][aria-expanded=true]]:min-w-[64rem] tw:md:flex-1 tw:md:max-w-max` : base}
      data-controller="ui--collapse ui--alert" data-ui--collapse-param-value="json"
      data-ui--collapse-direction-value="horizontal"><article class="twgutter tw:w-full tw:min-w-0 tw:space-y-6
      tw:rounded-lg tw:border tw:border-t-4 tw:border-vellum tw:border-t-blueprint tw:bg-paper tw:pt-4 tw:pb-6 tw:text-ink tw:[--gutter:--spacing(6)]
      ${comparing ? 'tw:md:max-w-[56rem] tw:lg:flex-1' : 'tw:lg:w-[56rem] tw:lg:shrink-0'}">${header}${specs}${this.description()}${this.sizes()}${this.components()}</article><aside
      id=${jsonPanelId} class="twjson-panel tw:hidden tw:w-full tw:min-w-0 tw:lg:relative tw:lg:w-[28rem] tw:lg:shrink-0" data-ui--collapse-target="content">${
        jsonDisplay({ data: this.data, small: true, noMaxHeight: true })}</aside></div>`
  }

  #photo (photo, titleText) {
    return html`<div class="tw:group tw:order-first" data-controller=${present(photo) ? 'bikebook--image-fallback' : nothing} data-broken=${present(photo) ? nothing : ''}>${present(photo)
      ? html`<a target="_blank" rel="noopener" class="tw:mb-6 tw:block tw:aspect-[3/2] tw:rounded-md tw:border tw:border-vellum tw:bg-white tw:p-2 tw:group-data-broken:hidden"
        href=${photo}><img alt=${titleText} loading="lazy" class="tw:size-full tw:rounded-sm tw:object-contain" data-action="error->bikebook--image-fallback#fail" src=${photo}></a>`
      : nothing}<div class="tw:mb-6 tw:hidden tw:aspect-[3/2] tw:flex-col tw:items-center tw:justify-center tw:gap-2 tw:rounded-md
      tw:border tw:border-dashed tw:border-vellum tw:text-gray-400 tw:group-data-broken:flex tw:dark:text-gray-500"><img
      alt="" class="tw:h-16 tw:w-16" src=${this.kit.placeholder_url}><span class="tw:text-sm">No photo</span></div></div>`
  }

  // Values by their vocabulary names, then the frame's mount labels and each suspension's values
  #normalize (data) {
    const vehicle = this.presenter.named(this.kit.schemas.vehicle, data)
    const frame = vehicle.frame && { ...vehicle.frame, ...this.#frameMounts(vehicle.frame, vehicle.sizes) }
    const suspension = Object.fromEntries(Object.keys(this.kit.viewer.suspensions)
      .map((position) => [position, this.#suspension(vehicle, position)]).filter(([, values]) => values != null))
    return { ...vehicle, frame, suspension }
  }

  #frameMounts (frame, sizes) {
    if (!frame.mounts) return {}
    const noted = frame.mounts.map((mount) => mount.sizes ? { ...mount, description: compact([this.sizeRange(mount.sizes, sizes), mount.description]).join(', ') } : mount)
    const bottles = noted.filter((mount) => mount.type === 'bottle')
    const mounts = noted.filter((mount) => mount.type !== 'bottle')
    return { mounts: mounts.map((mount) => this.#mountLabel(mount)), bottle_mounts: bottles.map((mount) => this.#bottleMountLabel(mount)) }
  }

  #suspension (vehicle, position) {
    const spec = this.kit.viewer.suspensions[position]
    // [travel, size names] in the order the sizes first give each travel
    const sizeTravels = []
    for (const size of array(vehicle.sizes)) {
      const travel = size.geometry?.[spec.size_travel]
      if (travel == null) continue
      const entry = sizeTravels.find(([value]) => value === travel)
      entry ? entry[1].push(size.name) : sizeTravels.push([travel, [size.name]])
    }
    const values = slice(vehicle.suspension, Object.keys(this.kit.viewer.suspension_fields[position]))
    if (blank(values) && sizeTravels.length === 0) return null

    const component = vehicle.components?.find((each) => each.type === spec.component)
    return Object.fromEntries(Object.entries({ ...values, size_travels: sizeTravels, component }).filter(([, value]) => value != null))
  }

  #mountLabel (mount) {
    const place = this.#mountPlace(mount)
    const where = place == null ? null : place.startsWith('under') ? place : `on ${place}`
    return upcaseFirst(compact([this.presenter.positionLabel(mount.position), mount.holes != null ? `${mount.holes}-hole` : null,
      mount.type.replaceAll('_', ' '), where, mount.description != null ? `(${mount.description})` : null]).join(' '))
  }

  #bottleMountLabel (mount) {
    const notes = compact([mount.holes != null ? `${mount.holes}-hole` : null, mount.description])
    return upcaseFirst(compact([this.#mountPlace(mount) ?? 'bottle', notes.length ? `(${notes.join(', ')})` : null]).join(' '))
  }

  #mountPlace (mount) {
    return mount.location?.replace(/_\d+$/, '').replaceAll('_', ' ')
  }

  // the size names in `sizes`' order, runs of neighbours as a range: "S–L, XL"
  sizeRange (names, sizes = this.vehicle.sizes) {
    const order = array(sizes).map((size) => size.name)
    const position = (name) => order.includes(name) ? order.indexOf(name) : order.length
    const sorted = [...names].sort((a, b) => position(a) - position(b))
    const runs = sorted.reduce((all, name, index) => {
      const previous = sorted[index - 1]
      if (index > 0 && order.includes(previous) && order.indexOf(name) === order.indexOf(previous) + 1) all.at(-1).push(name)
      else all.push([name])
      return all
    }, [])
    return runs.map((run) => [...new Set([run[0], run.at(-1)])].join('–')).join(', ')
  }

  onSizes (content, names) {
    return names ? join(compact([content, `on ${this.sizeRange(names)}`]), ' ') : content
  }

  // one order, down the left column and on under the photo, breaking where the taller column is shortest
  specColumns (photo, left, rest) {
    const shown = left.filter((block) => block !== nothing)
    const blocks = [...shown, ...rest.filter((block) => block !== nothing)].map((block) => {
      const fragment = document.createDocumentFragment()
      render(block, fragment)
      return fragment
    })
    // compared panels sit side by side, so each breaks at the same section
    const split = this.comparing ? shown.length : this.#shortestSplit(blocks, shown.length)
    return [blocks.slice(0, split), [photo, ...blocks.slice(split)]]
  }

  // the first split, from `from` on, whose taller column is shortest beside the photo
  #shortestSplit (blocks, from) {
    // a <br> line is about ⅔ of a row, and a section's bottom margin ¾
    const rows = blocks.map((block) => block.querySelectorAll('h2, h3, dt, tr').length + block.querySelectorAll('br').length * 0.66 + 0.75)
    const height = (at) => Math.max(sum(rows.slice(0, at)), this.kit.viewer.photo_rows + sum(rows.slice(at)))
    return Array.from({ length: blocks.length - from + 1 }, (_, index) => from + index).reduce((best, at) => height(at) < height(best) ? at : best)
  }

  differs (...keys) {
    const dig = (vehicle) => keys.reduce((value, key) => value?.[key], vehicle)
    return this.others.some((other) => !equal(dig(other), dig(this.vehicle)))
  }

  highlight (differs) {
    return differs ? 'tw:spec-diff tw:-mx-2 tw:rounded-r-sm tw:px-2 tw:py-1' : ''
  }

  identity () {
    const { presenter, vehicle } = this
    const row = (label, key, value = vehicle[key], differs = this.differs(key)) => definitionListRow({ label: presenter.diffLabel(label, differs), value })
    const configuration = vehicle.model_configuration
    const label = this.kit.model_configurations[configuration]
    const yearRangeDiffers = this.others.some((other) => !equal([other.first_year, other.final_year], [vehicle.first_year, vehicle.final_year]))
    return section({
      content: join([
        definitionListRow({ label: 'ID', content: copyableId({ id: this.value }) }),
        row('Model group', 'vehicle_model_group'),
        configuration !== 'complete' || this.differs('model_configuration')
          ? row('Configuration', 'model_configuration', configuration === 'complete' ? html`<span class="twless-strong">${label}</span>` : label)
          : '',
        row('Years', null, this.yearRange(), yearRangeDiffers),
        row('Markets', 'markets', vehicle.markets?.join(', ')),
        row('Vehicle type', 'type'),
        row('Propulsion', 'propulsion'),
        row('Primary activity', 'primary_activity', this.withoutParenthetical(vehicle.primary_activity)),
        row('Handlebar', 'handlebar_type', this.withoutParenthetical(vehicle.handlebar_type))
      ])
    })
  }

  yearRange () {
    const { first_year: first, final_year: final } = this.vehicle
    if (blank(first)) return null
    if (final === first) return String(first)
    return join([first, ' – ', presence(final) ?? 'current'])
  }

  specRows (key, fields = key === 'frame' ? this.kit.viewer.frame_fields : this.kit.schemas.vehicle[key].fields, labels = {}) {
    return this.presenter.rowsFor(fields, this.vehicle[key], { labels, others: this.others.map((other) => other[key]), collapse: ['bottom_bracket'] })
      .map(([label, value, ...rest]) => [label, this.specValue(value, rest.at(-1)), ...rest])
  }

  specValue (value, key) {
    if (value == null) return value

    if (key === 'headset') return this.withTooltip(this.shisCode(value, 'tw:text-sm'), this.headsetTooltip(value))
    if (key === 'bottom_bracket') return this.bottomBracket(value)
    if (key === 'cable_routing') return this.tooltipped(value, this.kit.viewer.cable_routing_tooltips)
    if (key === 'front') return this.measurements(value, 'teeth', '/')
    if (key === 'rear') return this.cogRange(value)
    return value
  }

  // a name's parenthetical moves to its tooltip
  withoutParenthetical (name) {
    const [, head, detail, tail] = String(name ?? '').match(/^(.*?)\s*\(([^)]*)\)(.*)$/) ?? []
    return detail === undefined ? name : this.withTooltip(`${head}${tail}`, detail)
  }

  tooltipped (value, tooltips) {
    const text = tooltips[value]
    return text ? this.withTooltip(value, text) : value
  }

  withTooltip (content, body) {
    return this.keepTogether(content, tooltip({ body }))
  }

  // keep_together: the content's last word stays on the tooltip's line, unless markup ends the content
  keepTogether (content, tip) {
    const parts = partsOf(content).filter((part) => part !== '' && part != null && part !== nothing)
    const lastMarkup = parts.findLastIndex((part) => typeof part !== 'string' && typeof part !== 'number')
    const [, head, last] = parts.slice(lastMarkup + 1).join('').match(KEEP_TOGETHER) ?? []
    if (!last || (lastMarkup >= 0 && !head)) return html`<span class="tw:whitespace-nowrap">${content} ${tip}</span>`
    return join([...parts.slice(0, lastMarkup + 1), head ?? '', html`<span class="tw:whitespace-nowrap">${last} ${tip}</span>`])
  }

  measurements (values, unit, separator) {
    const { presenter } = this
    return join([...values.slice(0, -1).map((value) => presenter.measurement(value)), presenter.measurement(values.at(-1), unit)], separator)
  }

  // `rear` lists at least its smallest and largest cog, so two entries are a range
  cogRange (cogs) {
    const ends = [...new Set([cogs[0], cogs.at(-1)])]
    const range = this.measurements(ends, 'teeth', '–')
    return ends.length < cogs.length ? this.withTooltip(range, cogs.join(', ')) : range
  }

  bottomBracket (bottomBracket) {
    const shell = bottomBracket.shell ?? html`<span class="twless-strong">Unknown shell</span>`
    const rows = this.presenter.rowsFor(this.kit.schemas.vehicle.frame.fields.bottom_bracket.fields, bottomBracket)
    return this.withTooltip(join([shell, ...array(bottomBracket.spindle)], ', '), this.tooltipRows(rows))
  }

  suspension () {
    const { presenter } = this
    const rows = Object.entries(this.vehicle.suspension).map(([position, values]) => definitionListRow({
      label: presenter.diffLabel(presenter.positionLabel(position), this.differs('suspension', position)), value: this.suspensionSummary(position, values)
    }))
    return section({ heading: 'Suspension', content: rows.length ? join(rows) : null })
  }

  suspensionSummary (position, suspension) {
    const { presenter } = this
    const component = suspension.component
    const name = presence(component?.description?.split(',')[0].replace(/\s*\d+(\.\d+)?\s?mm$/i, ''))
    const { rear_shock_length: length, rear_shock_stroke: stroke, rear_shock_mount: mount } = suspension
    const size = truthy(length) ? this.measurements(compact([length, stroke]), 'mm', ' × ') : null
    const [leadKey, lead] = this.travelLead(suspension, this.kit.viewer.suspensions[position].travel) ?? []
    const parts = compact([lead, presence(join(compact([size, name ?? (size ? 'shock' : null)]), ' ')), truthy(length) ? null : this.millimeters(stroke, ' stroke')])
    const summary = parts.length ? join(parts, ', ') : `${upcaseFirst(mount)} shock mount`
    const dimensions = except(this.kit.schemas.component_dimensions, ['travel', 'extra_measurements'])
    const componentRows = component
      ? [[component.type_detail ?? component.type, component.description], ['Manufacturer', component.manufacturer], ...presenter.rowsFor(dimensions, component.dimensions)]
          .filter((row) => present(row[1]))
      : []
    const rows = [...presenter.rowsFor(this.kit.viewer.suspension_fields[position], suspension, { labels: this.kit.viewer.suspension_labels }), ...componentRows]
    const shown = compact([leadKey, 'rear_shock_length', 'rear_shock_stroke', parts.length ? null : 'rear_shock_mount'])
    const unshown = rows.some((row) => !shown.includes(row.length > 2 ? row.at(-1) : null) && !equal(row[1], name))
    return unshown ? this.withTooltip(summary, this.tooltipRows(rows)) : summary
  }

  // [the field the summary leads with, its text]; travel can come from the fork or shock itself
  travelLead (suspension, travelKey) {
    const travel = suspension[travelKey] ?? suspension.component?.dimensions?.travel
    if (truthy(travel) || suspension.size_travels.length) return [travelKey, this.travelSummary(travel, suspension.size_travels)]

    const max = suspension.max_fork_travel
    return truthy(max) ? ['max_fork_travel', join(['Up to ', this.millimeters(max, ' fork')])] : null
  }

  // the given travel, else the one most sizes share, with each size's other travel after it
  travelSummary (travel, sizeTravels) {
    const base = travel ?? sizeTravels.reduce((most, entry) => entry[1].length > most[1].length ? entry : most)[0]
    return join([this.millimeters(base), ...sizeTravels.filter(([value]) => value !== base).map(([value, names]) => this.onSizes(this.millimeters(value), names))], ', ')
  }

  tooltipRows (rows) {
    return join(rows.map(([label, value, unit, , key]) => html`<span class="tw:block">${label}: ${this.presenter.measurement(value, unit, key)}</span>`), ' ')
  }

  headsetTooltip (code) {
    return join([
      html`<span class="tw:mb-2 tw:block tw:text-lg">${this.presenter.shisLabel(code) ?? ''}</span>`,
      html`<span class="tw:block">${this.shisCode(code)} is the standardized headset identification system. <a class="twlink" target="_blank"
        rel="noopener" href=${this.kit.shis.url}>Read more here</a></span>`
    ], ' ')
  }

  shisCode (code, size = 'tw:text-xs') {
    return html`<code class="tw:rounded-sm tw:border tw:border-vellum tw:px-1.5 tw:py-0.5 tw:font-spec tw:whitespace-nowrap ${size}">${code}</code>`
  }

  millimeters (value, suffix = null) {
    return truthy(value) ? join(compact([this.presenter.measurement(value, 'mm'), suffix])) : null
  }

  // One per motor index across the compared vehicles
  motorSections () {
    const [motors, ...othersMotors] = [this.vehicle, ...this.others].map((vehicle) => vehicle.motors ?? [])
    const count = Math.max(motors.length, ...othersMotors.map((each) => each.length))
    return Array.from({ length: count }, (_, index) => {
      const motor = motors[index]
      const heading = count === 1 ? 'Motor & Battery' : motor?.drive_wheel ? `${this.presenter.humanize(motor.drive_wheel)} motor` : `Motor ${index + 1}`
      return motorSection({ presenter: this.presenter, heading, motor: motor ?? {}, others: othersMotors.map((each) => each[index] ?? {}) })
    })
  }

  byPosition (collection, position) {
    return array(collection).find((item) => equal(item.position, position))
  }

  // The Wheels and Brakes sections
  positioned (heading, key, fallback, summary) {
    const { presenter } = this
    if (blank(this.vehicle[key])) return nothing
    return section({
      heading,
      content: join(this.vehicle[key].map((item) => {
        const differs = this.others.some((other) => !equal(this.byPosition(other[key], item.position), item))
        return definitionListRow({ label: presenter.diffLabel(presenter.positionLabel(item.position) ?? fallback, differs), content: summary(item) })
      }))
    })
  }

  builtWheels (vehicle = this.vehicle) {
    return array(vehicle.wheels).filter((wheel) => wheel.configured !== false)
  }

  // the wheels the frame takes but the build doesn't come with, as [bsd, max_tire_width, positions]
  clearances (vehicle = this.vehicle) {
    const groups = new Map()
    for (const wheel of array(vehicle.wheels).filter((each) => each.configured === false)) {
      const key = JSON.stringify([wheel.bsd ?? null, wheel.max_tire_width ?? null])
      if (!groups.has(key)) groups.set(key, [wheel.bsd ?? null, wheel.max_tire_width ?? null, []])
      groups.get(key)[2].push(...array(wheel.position))
    }
    return [...groups.values()].map(([bsd, max, positions]) => [bsd, max, [...new Set(positions)].sort()])
  }

  wheels () {
    const { presenter } = this
    if (blank(this.vehicle.wheels)) return nothing

    const rows = this.builtWheels().map((wheel) => {
      const differs = this.others.some((other) => !equal(this.byPosition(this.builtWheels(other), wheel.position), wheel))
      return definitionListRow({ label: presenter.diffLabel(presenter.positionLabel(wheel.position) ?? 'Wheel', differs), content: this.wheelSummary(wheel) })
    })
    const clearances = this.clearances()
    const differs = this.others.some((other) => !equal(this.clearances(other), clearances))
    const alsoFits = clearances.length ? definitionListRow({ label: presenter.diffLabel('Also fits', differs), content: this.clearanceSummary(clearances) }) : nothing
    return section({ heading: 'Wheels', content: join([...rows, alsoFits]) })
  }

  clearanceSummary (clearances) {
    const built = [...new Set(this.builtWheels().flatMap((wheel) => array(wheel.position)))].sort()
    return join(clearances.map(([bsd, max, positions]) => {
      const wheel = join(compact([bsd ? this.wheelSizeName(bsd) : null, equal(positions, built) ? null : `on the ${this.presenter.positionLabel(positions).toLowerCase()}`]), ' ')
      return join(compact([presence(wheel), max ? this.tireWidthSummary(max, 'tire max') : null]), ', ')
    }), '; ')
  }

  wheelSummary (wheel) {
    const summary = join(compact([
      this.onSizes(wheel.bsd != null ? this.wheelSizeName(wheel.bsd) : null, wheel.sizes),
      wheel.tire_width != null ? this.tireWidthSummary(wheel.tire_width) : null,
      wheel.tire_system?.replaceAll('_', ' '),
      wheel.cassette_interface != null ? `${wheel.cassette_interface} cassette` : null,
      wheel.dropout != null ? `${wheel.dropout.replaceAll('_', ' ')} dropout` : null,
      this.axleSummary(wheel)
    ]), ', ')
    return wheel.max_tire_width != null ? join([summary, html`<br>`, this.tireWidthSummary(wheel.max_tire_width, 'tire max')]) : summary
  }

  axleSummary (wheel) {
    const details = this.kit.viewer.axle_details
    const name = wheel.axle?.replaceAll('_', ' ')
    if (Object.keys(details).filter((key) => key !== 'axle').every((key) => !truthy(wheel[key]))) return name

    const rows = Object.entries(details).filter(([key]) => truthy(wheel[key])).map(([key, label]) => html`<span class="tw:block">${label}: ${
      typeof wheel[key] === 'number' ? this.millimeters(wheel[key]) : wheel[key].replaceAll('_', ' ')}</span>`)
    return this.withTooltip(name ?? 'axle', join(rows))
  }

  tireWidthSummary (tireWidth, label = 'tire') {
    const { presenter } = this
    if (tireWidth <= 50) return join([presenter.measurement(tireWidth, 'mm'), ` ${label}`])

    // (tire_width / 25.4).round(1) is a Float, so a whole inch still reads 2.0
    const inches = presenter.labeled(presenter.rounded(tireWidth / 25.4).toFixed(1), 'in')
    return this.keepTogether(join([inches, ` ${label}`]), tooltip({ text: `${tireWidth} mm` }))
  }

  wheelSizeName (bsd) {
    const size = this.presenter.vocabulary.wheel_sizes[bsd]
    if (!size) return join([this.presenter.measurement(bsd, 'mm'), ' BSD'])
    if (this.presenter.standardWheelSizes.has(Number(bsd))) return size.name
    return this.keepTogether(size.name, tooltip({ body: join(compact([presence(size.description), `${bsd} mm BSD`]).map((line) => html`<span class="tw:block">${line}</span>`)) }))
  }

  brakeSummary (brake) {
    const typeAndRotor = presence(join(compact([brake.type?.replace(/^Disc (\w+)$/, '$1 disc'), this.millimeters(brake.rotor_diameter, ' rotor')]), ', '))
    const summary = join(compact([this.onSizes(typeAndRotor, brake.sizes), presence(brake.caliper_mount?.replace(/^Disc /, ''))]), ', ')
    return brake.max_rotor_diameter != null ? join([summary, html`<br>`, this.millimeters(brake.max_rotor_diameter, ' rotor max')]) : summary
  }

  drivetrain () {
    const { presenter, vehicle } = this
    const fields = slice(this.kit.schemas.vehicle.frame.fields, this.kit.viewer.drivetrain_frame_fields)
    const counted = Object.fromEntries(Object.entries(this.kit.viewer.gearing_labels)
      .map(([position, label]) => [position, array(vehicle.gearing?.[position]).length === 1 ? label : `${label}s`]))
    const rows = [...this.specRows('gearing', this.kit.schemas.vehicle.gearing.fields, counted), ...this.specRows('frame', fields)]
    if (blank(vehicle.drivetrain) && rows.length === 0) return nothing

    const sorted = (gearing) => array(gearing).sort()
    const differs = this.others.some((other) => !equal(sorted(other.drivetrain), sorted(vehicle.drivetrain)))
    const gearing = array(vehicle.drivetrain)
    const labels = equal(sorted(gearing), ['1 Front', '1 Rear']) ? ['Singlespeed'] : gearing
    return html`<section class="tw:mb-6 tw:break-inside-avoid tw:space-y-2 ${this.highlight(differs)}"><h2 class="tw:spec-eyebrow">Drivetrain</h2>${present(vehicle.drivetrain)
      ? html`<div class="tw:flex tw:flex-wrap tw:gap-2">${labels.map((label) => html`<span class="tw:rounded-sm tw:border tw:border-vellum tw:bg-paper tw:px-2 tw:py-0.5 tw:font-spec
        tw:text-xs tw:text-ink">${this.tooltipped(label, this.kit.viewer.drivetrain_tooltips)}</span>`)}</div>`
      : nothing}${rows.length ? definitionListContainer({ content: presenter.measurementRows(rows) }) : nothing}</section>`
  }

  description () {
    const description = this.vehicle.description
    if (blank(description)) return nothing

    const differs = this.others.some((other) => String(other.description ?? '') !== String(description))
    return disclosure({
      param: 'description',
      label: 'description',
      heading: 'Description',
      content: html`<div class="tw:text-sm tw:text-gray-700 tw:dark:text-gray-300 ${this.highlight(differs)}"><p
        class="tw:truncate tw:group-has-[[aria-expanded=true]]/disclosure:hidden">${description}</p><div data-ui--collapse-target="content"
        class="tw:hidden tw:space-y-2">${simpleFormat(description)}</div></div>`
    })
  }

  sizes () {
    const sizes = this.vehicle.sizes
    if (blank(sizes)) return nothing

    const others = this.others.map((other) => other.sizes)
    return disclosure({
      param: 'sizes',
      label: 'sizes',
      heading: html`Sizes & geometry <span class="tw:ml-1 tw:font-spec tw:text-sm tw:font-normal tw:tracking-normal tw:text-ink/50 tw:normal-case">${numberDisplay(sizes.length)}</span>`,
      content: html`<div data-ui--collapse-target="content" class="twgutter-bleed tw:flex tw:gap-4 tw:overflow-x-auto tw:pb-3.5">${
        sizes.map((size) => geometryCard({ presenter: this.presenter, size, others }))}</div>`
    })
  }

  components () {
    const components = this.vehicle.components
    if (blank(components)) return nothing

    const groups = Object.keys(this.kit.component_groups)
    const group = (type) => this.presenter.componentGroups.get(type) ?? groups.at(-1)
    const label = (component) => [component.type, component.type_detail].filter(present).join(' · ').toLowerCase()
    const tables = groups.flatMap((name) => {
      const members = components.filter((component) => group(component.type) === name)
      if (members.length === 0) return []

      const others = this.others.map((other) => array(other.components).filter((component) => group(component.type) === name))
      const sorted = [...members].sort((a, b) => label(a) < label(b) ? -1 : label(a) > label(b) ? 1 : 0)
      return [componentGroup({ presenter: this.presenter, name, components: sorted, others })]
    })
    return html`<section class="tw:space-y-4"><h2 class="tw:spec-eyebrow">Components</h2>${tables}</section>`
  }
}

// A section whose heading's chevron opens and closes its content (ui--collapse), rendered open
// unless the content is hidden
const disclosure = ({ param, label, heading, content }) => html`<section class="tw:group/disclosure tw:space-y-2"
  data-controller="ui--collapse" data-ui--collapse-param-value=${param}><div class="tw:flex tw:items-baseline tw:justify-between tw:gap-3"><h2
  class="tw:spec-eyebrow">${heading}</h2>${collapse({ chevron: true, size: 'sm', attributes: { 'aria-label': `Toggle ${label}` } })}</div>${content}</section>`

// simple_format
const simpleFormat = (text) => String(text).replace(/\r\n?/g, '\n').split(/\n\n+/).map((paragraph) => {
  const lines = paragraph.split('\n')
  return html`<p>${lines.map((line, index) => index === 0 ? line : ['\n', lines[index - 1] && line ? html`<br>` : nothing, line])}</p>`
})
