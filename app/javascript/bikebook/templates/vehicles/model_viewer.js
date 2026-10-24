import { html, nothing, render } from 'lit-html'
import { frameGeometry, OVERALL_LENGTH_ESTIMATE } from 'bikebook/frame_geometry'
import { copyButton } from 'bikebook/templates/ui/copy_button'
import { missing, numberDisplay } from 'bikebook/templates/helpers'
import { collapse } from 'bikebook/templates/ui/collapse'
import { definitionListContainer } from 'bikebook/templates/ui/definition_list/container'
import { definitionListRow } from 'bikebook/templates/ui/definition_list/row'
import { jsonDisplay } from 'bikebook/templates/ui/json_display'
import { tooltip } from 'bikebook/templates/ui/tooltip'
import { componentGroup, matchingRow, pairedComponents } from 'bikebook/templates/vehicles/component_group'
import { geometryCard } from 'bikebook/templates/vehicles/geometry_card'
import { modelYears } from 'bikebook/templates/vehicles/model_years'
import { motorSection } from 'bikebook/templates/vehicles/motor_section'
import { bikeSummary } from 'bikebook/templates/vehicles/bike_summary'
import { certificationBadges, certificationsOf, classBadges } from 'bikebook/templates/vehicles/page_badges'
import { removeLink } from 'bikebook/templates/vehicles/remove_link'
import { disclosure, section } from 'bikebook/templates/vehicles/section'
import { andSentence, array, blank, compact, equal, except, isNumber, join, partsOf, presence, present, slice, sum, truthy, upcaseFirst } from 'bikebook/templates/values'

// Ruby's \s, which a thin space isn't
const KEEP_TOGETHER = /^([^]*[ \t\r\n\f\v])?([^ \t\r\n\f\v]+)$/

const drivetrainLabels = (drivetrain) => equal(array(drivetrain).sort(), ['1 Front', '1 Rear']) ? ['Singlespeed'] : array(drivetrain)

// "Air" or "Coil", and a lockout "Yes" or "No"
const suspensionValue = (value, key) => key === 'spring' && value ? upcaseFirst(value) : key === 'lockout' && value != null ? (value ? 'Yes' : 'No') : value

// "Shimano GRX RX610 1X12S · electronic", its maker unless the description starts with it
const groupsetSummary = ({ groupset }) => {
  if (blank(groupset)) return null
  const { manufacturer, description, electronic } = groupset
  const named = manufacturer && String(description ?? '').toLowerCase().startsWith(manufacturer.toLowerCase())
  const name = compact([named ? null : manufacturer, description]).join(' ')
  return electronic ? join([name, 'electronic'], ' · ') : name
}
// "Cargo Bike Rear · Kids & Women's · Long tail": its type, target riders and detail, and a step-through frame's after,
// its top tube named or not
export const typeLabel = (each) => [each.type, array(each.target_riders).join(' & '), each.type_detail,
  /^step[_-]through$/i.test(each.frame?.top_tube ?? '') && 'Step-through'].filter(present).join(' · ')

// One vehicle's card, marked where it differs from `others`
export const modelViewer = (args) => new ModelViewer(args).render()

// A mode the bike is sold with. One an app update unlocks is stock, not optional, as EbikeRuleServices::BikebookVehicles has it
const stock = ({ availability }) => [undefined, null, 'stock', 'app_update'].includes(availability)

const WIDE_TIRE = 50
const MAX_LOAD = 'Max load (rider + cargo)'
const GROSS_WEIGHT = 'Gross weight rating (bike + rider + cargo)'
const FRAME_LABELS = { max_weight_total: MAX_LOAD, gross_weight_rating: GROSS_WEIGHT }

export const US_CLASS = /^evc\/us\/class_(\d)$/
// (tire_width / 25.4).round(1) is a Float, so a whole inch still reads 2.0
const tireInches = (presenter, millimeters) => presenter.labeled(presenter.rounded(millimeters / 25.4).toFixed(1), 'in', presenter.kit.inches)
const brakeType = (brake) => brake?.type?.replace(/^Disc (\w+)$/, '$1 disc')
const at = (items, position, size) => array(items).filter((item) => array(item.position).includes(position) && (!item.sizes || array(item.sizes).includes(size?.name)))

// A vehicle's front and rear in `size`, as the comparison table lists them: the built wheel's [key, number, content]
// parts, its tire's carrying its width, and the widest tire any of its wheels there takes
export const wheelsAt = (presenter, data, size) => {
  const viewer = new ModelViewer({ presenter, data, others: [] })
  return Object.fromEntries(['front', 'rear'].map((position) => {
    const built = at(viewer.builtWheels(), position, size)[0]
    const widths = at(viewer.vehicle.wheels, position, size).map((wheel) => wheel.max_tire_width).filter((width) => typeof width === 'number')
    return [position, {
      parts: built && viewer.wheelParts({ ...built, sizes: null }, { fitting: false }).map(([key, content]) => [key, { size: built.bsd, tire: built.tire_width }[key] ?? null, content]),
      maxTire: widths.length ? Math.max(...widths) : null
    }]
  }))
}

const highest = (values) => values.some(isNumber) ? Math.max(...values.filter(isNumber)) : null
// The highest `key` of any of a vehicle's motors' operating modes
const modes = (key) => (vehicle) => highest(array(vehicle.motors).flatMap((motor) => array(motor.operating_modes)).map((mode) => mode[key]))

// cargo_bike, cargo_tricycle and their _rear kinds
export const isCargo = (data) => /^cargo_/.test(data.type ?? '')

// A vehicle's max load or gross weight rating, or else its rider limit in `size`, and its cargo area
export const cargoAt = (presenter, data, size) => new ModelViewer({ presenter, data, others: [] }).cargo(size)

export const tireWidth = (presenter, width) => new ModelViewer({ presenter, data: {}, others: [] }).tireWidthSummary(width, null)

export const wheelSize = (presenter, bsd) => new ModelViewer({ presenter, data: {}, others: [] }).wheelSizeName(bsd)

// A vehicle's names, photo and the fields the Overview lists
export const basicsOf = ({ presenter, data, outOfClassId }) => new ModelViewer({ presenter, data, others: [], outOfClassId }).basics()

// A vehicle's stock photo in `frame`, without the rest of what basicsOf works out
export const photoOf = ({ presenter, data }, frame) => new ModelViewer({ presenter, data, others: [] }).stockPhoto(frame)

// A vehicle's sizes, each with its geometry, `selectedSize` ringed and marked where they differ from `others`', the rest
// linked to `sizePath(name)`, and each figure lettered as its drawing has it by `lettering`, geometryCard's letters,
// highlight and figurePath
export const sizesOf = ({ presenter, data, others, selectedSize, sizePath, lettering }) =>
  new ModelViewer({ presenter, data, others, selectedSize, sizePath, lettering }).sizes()

// A vehicle's electric summary beside its motors, each with its battery, marked where they differ from `others`'
export const motorsOf = ({ presenter, data, others, outOfClassId }) => {
  const viewer = new ModelViewer({ presenter, data, others, outOfClassId })
  return sideBySide([viewer.electricSummary(), viewer.motorSections()])
}

// A vehicle's frame, wheels and brakes beside its suspension and drivetrain, marked where they differ from `others`'
export const runningGearOf = ({ presenter, data, others }) => {
  const viewer = new ModelViewer({ presenter, data, others })
  return sideBySide([[viewer.frame(), viewer.wheels(), viewer.positioned('Brakes', 'brakes', 'Brake', (brake) => viewer.brakeSummary(brake))], [viewer.suspension(), viewer.drivetrain()]])
}

// Side by side once their container is wide enough, else one after the other
const sideBySide = (columns) => html`<div class="tw:@container"><div class="tw:flex tw:flex-col tw:@min-[600px]:flex-row tw:@min-[600px]:gap-6">${columns.map((column) =>
  html`<div class="tw:contents tw:@min-[600px]:block tw:@min-[600px]:min-w-0 tw:@min-[600px]:flex-1">${column}</div>`)}</div></div>`

// Each of `vehicles`' components by group, by its `key`, marked where they differ from its `others`', each group
// listing a row for every component any of them has, so each card's rows line up with the rest's
export const componentsOf = ({ presenter, vehicles, others }) => {
  const viewers = vehicles.map(({ data }) => new ModelViewer({ presenter, data, others: [] }))
  const groups = viewers[0].componentRows(viewers.map((viewer) => viewer.vehicle))
  return new Map(vehicles.map(({ key }, index) => [key, html`<div class="tw:space-y-4">${viewers[index].components({
    groups, index, compared: others(key).map((other) => vehicles.findIndex(({ data }) => data === other))
  })}</div>`]))
}

class ModelViewer {
  // `outOfClassId` the viewing state's out of class marker, evc/out_of_class/us/ca, where its law bars a Class 3's throttle
  constructor ({ presenter, data, value, comparing, idSuffix, others, removePath, selectedSize, sizePath, outOfClassId, lettering }) {
    this.presenter = presenter
    this.kit = presenter.kit
    this.data = data
    this.vehicle = this.#normalize(data)
    this.outOfClass = outOfClassId ? this.#throttledClass3() : null
    this.others = others.map((other) => this.#normalize(other))
    Object.assign(this, { value, comparing, idSuffix, removePath, selectedSize, sizePath, outOfClassId, lettering })
  }

  render () {
    const { vehicle, comparing, presenter } = this
    const jsonPanelId = `vehicle-model-json-${this.idSuffix}`
    const base = 'tw:flex tw:flex-col tw:gap-6 tw:transition tw:duration-300 tw:lg:flex-row tw:lg:items-stretch'
    const titleText = [vehicle.manufacturer, vehicle.model].filter(present).join(' ')
    const header = html`<header><div class="tw:flex tw:items-start tw:gap-4">${present(vehicle.manufacturer)
      ? html`<p class="tw:mb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">${vehicle.manufacturer}</p>`
      : nothing}${removeLink({ label: `Remove ${titleText}`, href: this.removePath })}</div><div class="tw:flex tw:items-baseline tw:justify-between tw:gap-4"><div class="tw:text-2xl tw:leading-tight"><h1
      class="tw:inline tw:font-extrabold">${vehicle.model}</h1> ${copyButton({ value: this.value, label: 'Copy ID', tooltip: true })}</div>${collapse({
        size: 'sm',
        htmlClass: 'tw:shrink-0 tw:whitespace-nowrap',
        attributes: { 'aria-controls': jsonPanelId, 'aria-label': 'Toggle JSON' },
        content: html`<code>{ }</code>`
      })}</div></header>`
    const columns = this.specColumns(this.photo(vehicle.stock_photo, titleText), [
      this.identity(),
      modelYears({ presenter, years: vehicle.years, others: this.others.map((other) => other.years) }),
      this.suspension(),
      this.frame()
    ], [this.electricSummary(), ...this.motorSections()], [
      section({ heading: 'Cargo', content: presenter.measurementRows(this.specRows('cargo')) }),
      this.wheels(),
      this.positioned('Brakes', 'brakes', 'Brake', (brake) => this.brakeSummary(brake)),
      this.drivetrain()
    ])
    const specs = sideBySide(columns)
    return html`<div class=${comparing ? `${base} tw:md:min-w-[19rem] tw:md:has-[[aria-controls^=vehicle-model-json][aria-expanded=true]]:min-w-[64rem] tw:md:flex-1 tw:md:max-w-max` : base}
      data-controller="ui--collapse ui--alert" data-ui--collapse-param-value="json"
      data-ui--collapse-direction-value="horizontal"><article class="twgutter tw:w-full tw:min-w-0 tw:space-y-6
      tw:rounded-sm tw:border tw:border-gray-200 tw:dark:border-gray-700 tw:bg-white tw:dark:bg-gray-800 tw:pt-4 tw:pb-6 tw:[--gutter:--spacing(6)]
      ${comparing ? 'tw:md:max-w-[56rem] tw:lg:flex-1' : 'tw:lg:w-[56rem] tw:lg:shrink-0'}">${header}${specs}${this.description()}${this.sizesDisclosure()}${present(this.vehicle.components)
      ? html`<section class="tw:space-y-4"><h2 class="tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">Components</h2>${this.components()}</section>`
      : nothing}</article><aside
      id=${jsonPanelId} class="twjson-panel tw:hidden tw:w-full tw:min-w-0 tw:lg:relative tw:lg:w-[28rem] tw:lg:shrink-0" data-ui--collapse-target="content">${
        jsonDisplay({ data: this.data, small: true, noMaxHeight: true })}</aside></div>`
  }

  photo (photo, titleText, frame = 'tw:mb-6 tw:aspect-[3/2]') {
    return html`<div class="tw:group tw:order-first" data-controller=${present(photo) ? 'image-fallback' : nothing} data-broken=${present(photo) ? nothing : ''}>${present(photo)
      ? html`<a target="_blank" rel="noopener" class="${frame} tw:block tw:group-data-broken:hidden"
        href=${photo}><img alt=${titleText} loading="lazy" class="tw:size-full tw:rounded-sm tw:object-contain" data-action="error->image-fallback#fallBack" src=${photo}></a>`
      : nothing}<div class="${frame} tw:hidden tw:flex-col tw:items-center tw:justify-center tw:gap-2 tw:rounded-md tw:p-1
      tw:border tw:border-dashed tw:border-gray-200 tw:dark:border-gray-700 tw:text-gray-400 tw:group-data-broken:flex tw:dark:text-gray-500"><img
      alt="" class="tw:aspect-square tw:h-16 tw:min-h-0 tw:w-auto" src=${this.kit.placeholder_url}><span class="tw:text-sm tw:leading-none">No photo</span></div></div>`
  }

  // Values by their vocabulary names, then the frame's mount labels and each suspension's values
  #normalize (data) {
    const vehicle = this.presenter.named(this.kit.schemas.vehicle, data)
    const frame = vehicle.frame && { ...vehicle.frame, ...this.#frameMounts(vehicle.frame, vehicle.sizes) }
    const suspension = Object.fromEntries(Object.keys(this.kit.viewer.suspensions)
      .map((position) => [position, this.#suspension(vehicle, position)]).filter(([, values]) => values != null))
    return { ...vehicle, frame, suspension, type_name: typeLabel(vehicle), classifiedModes: this.#classifiedModes(data) }
  }

  // As EbikeRuleServices::Bike has it, a Class 3's throttle: 'stock' as it's sold with one, as a throttle propulsion
  // with no throttle mode is, or 'throttle' with an optional one
  #throttledClass3 () {
    const modes = this.vehicle.classifiedModes
    if (!modes.some(({ ids }) => ids.includes('evc/us/class_3'))) return null
    const throttles = modes.filter(({ mode }) => mode === 'throttle')
    if (throttles.length ? throttles.some(stock) : array(this.data.propulsion).includes('throttle')) return 'stock'
    return throttles.length ? 'throttle' : null
  }

  // An app update replaces the modes of its kind the bike leaves the factory with, as a Class 3 assist does a Class 1's
  #classifiedModes (data) {
    const modes = array(data.motors).flatMap((motor) => array(motor.operating_modes))
    const updated = new Set(modes.filter(({ availability }) => availability === 'app_update').map(({ mode }) => mode))
    return modes.filter(({ mode, availability }) => !(updated.has(mode) && [undefined, null, 'stock'].includes(availability)))
      .map(({ mode, availability, max_speed: maxSpeed, e_vehicle_classifications: ids }) => ({ mode, availability, maxSpeed, ids: array(ids) }))
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
    const values = vehicle.suspension?.[position]
    if (values == null && sizeTravels.length === 0) return null

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

  // Down the left column and on under the photo and the motors, which stay beneath it, breaking where
  // the taller column is shortest. Stacked, the sections keep their order: motors after the frame
  specColumns (photo, left, motors, rest) {
    const [shown, pinned, after] = [left, motors, rest].map((blocks) => blocks.filter((block) => block !== nothing).map((block) => {
      const fragment = document.createDocumentFragment()
      render(block, fragment)
      return fragment
    }))
    ;[...shown, ...pinned, ...after].forEach((fragment, index) => { fragment.firstElementChild.style.order = index })
    const blocks = [...shown, ...after]
    // compared panels sit side by side, so each breaks at the same section
    const split = this.comparing ? shown.length : this.#shortestSplit(blocks, pinned, shown.length)
    return [blocks.slice(0, split), [photo, ...pinned, ...blocks.slice(split)]]
  }

  // the first split, from `from` on, whose taller column is shortest beside the photo and motors
  #shortestSplit (blocks, pinned, from) {
    // a <br> line is about ⅔ of a row, and a section's bottom margin ¾
    const rows = (block) => block.querySelectorAll('h2, h3, dt, tr').length + block.querySelectorAll('br').length * 0.66 + 0.75
    const heights = blocks.map(rows)
    const beneath = this.kit.viewer.photo_rows + sum(pinned.map(rows))
    const height = (at) => Math.max(sum(heights.slice(0, at)), beneath + sum(heights.slice(at)))
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
    // `shown` presents the field's value, the others' as well as this one's
    const row = (label, key, shown = (value) => value) =>
      definitionListRow({ label, value: presenter.highlighted(shown(vehicle[key]), this.differs(key), this.others.map((other) => shown(other[key]))) })
    const configuration = vehicle.model_configuration
    const configurationName = (each) => each === 'complete'
      ? html`<span class="twless-strong">${this.kit.model_configurations[each]}</span>`
      : this.kit.model_configurations[each]
    const yearRangeDiffers = this.others.some((other) => !equal([other.first_year, other.final_year], [vehicle.first_year, vehicle.final_year]))
    const list = (value) => join(array(value), ', ')
    return section({
      content: join([
        row('Model group', 'vehicle_model_group'),
        configuration !== 'complete' || this.differs('model_configuration')
          ? row('Configuration', 'model_configuration', configurationName)
          : '',
        definitionListRow({ label: 'Years', value: presenter.highlighted(this.yearRange(), yearRangeDiffers) }),
        row('Markets', 'markets', list),
        row('Vehicle type', 'type_name'),
        row('Propulsion', 'propulsion', list),
        this.classifications(),
        row('Primary activity', 'primary_activity', (each) => this.withoutParenthetical(each)),
        row('Handlebar', 'handlebar_type', (each) => this.withoutParenthetical(each))
      ])
    })
  }

  stockPhoto (frame) {
    const { vehicle } = this
    return this.photo(vehicle.stock_photo, [vehicle.manufacturer, vehicle.model].filter(present).join(' '), frame)
  }

  basics () {
    const { vehicle } = this
    const description = present(vehicle.description) ? html`<div class="tw:space-y-2">${simpleFormat(vehicle.description)}</div>` : null
    return {
      manufacturer: vehicle.manufacturer,
      model: vehicle.model,
      photo: (frame) => this.stockPhoto(frame),
      electric: present(vehicle.motors),
      model_group: vehicle.vehicle_model_group,
      years: this.yearRange(),
      vehicle_type: presence(typeLabel(vehicle)),
      type: vehicle.type,
      e_vehicle_class: this.eVehicleClass(),
      cargo_vehicle: isCargo(this.data),
      cargo: this.cargo(),
      primary_activity: this.withoutParenthetical(vehicle.primary_activity),
      frame_material: present(vehicle.frame?.material) && present(vehicle.frame.material_detail)
        ? html`${vehicle.frame.material} <span class="tw:text-xs twless-strong">${vehicle.frame.material_detail}</span>`
        : vehicle.frame?.material,
      wheel_size: this.wheelSizes(),
      suspended: present(vehicle.suspension),
      suspension: this.suspensionTravels(),
      groupset: this.groupsetWithDrivetrain(),
      certification: present(vehicle.motors) ? certificationBadges(array(vehicle.motors).map((motor) => motor.certification)) : null,
      description
    }
  }

  // Each classification any operating mode has, compared by name: a tooltip's random id never equals another's.
  // One only an optional mode has goes on its own line, after the mode
  classifications () {
    const mine = this.#sortedClassifications(this.vehicle)
    const differs = this.others.some((other) => !equal(this.#sortedClassifications(other), mine))
    return definitionListRow({ label: 'E-vehicle class', value: this.presenter.highlighted(this.classificationNames(mine), differs) })
  }

  classificationNames ({ standard, optional }) {
    const tooltips = this.presenter.classificationTooltips()
    const optionals = optional.map(([name, mode]) => html`<span class="tw:block"><span class="tw:text-xs tw:text-gray-400 tw:dark:text-gray-500">w/ optional
      ${this.presenter.modeLabel(mode).toLowerCase()}</span> ${this.tooltipped(name, tooltips)}</span>`)
    return join([join(standard.map((name) => this.tooltipped(name, tooltips)), ', '), ...optionals])
  }

  // "Total length 6' 4", Cargo 2' 7" ?", each spelled out in its tooltip, over "Max load 200 kg ?". Without a `size`, as
  // the Overview has none, its total length, which a size's geometry has a row of its own for
  cargo (size) {
    const { presenter } = this
    const { length, width, volume } = this.data.cargo ?? {}
    const area = Object.entries({ length, width }).filter(([, mm]) => isNumber(mm))
    const total = size ? [] : this.#totalLengths()
    const range = (lengths, shown) => join(lengths.map(shown), '–')
    const totaled = total.length > 0
    const areaShown = area.length > 0
    const shortened = [
      totaled && join(['Total length ', range(total, (mm) => presenter.length(mm))]),
      (areaShown || isNumber(volume)) && join(['Cargo ', join([
        areaShown && join(area.map(([, mm]) => presenter.length(mm)), ' × '), isNumber(volume) && presenter.measurement(volume, 'l')
      ].filter(present), ', ')])
    ].filter(present)
    const spelled = [
      totaled && join(['Total length: ', range(total, (mm) => presenter.lengthInWords(mm))]),
      totaled && html`<span class="tw:text-gray-500 tw:dark:text-gray-400">(total length is ${OVERALL_LENGTH_ESTIMATE})</span>`,
      ...area.map(([key, mm]) => join([`Cargo ${key}: `, presenter.lengthInWords(mm)])),
      isNumber(volume) && join(['Cargo volume: ', presenter.measurement(volume, 'l')])
    ].filter(present)
    const lengths = shortened.length
      ? join([join(shortened, ', '), ' ', tooltip({ text: 'Lengths', body: join(spelled.map((line) => html`<span class="tw:block">${line}</span>`)) })])
      : null
    const lines = [lengths, this.#cargoWeight(size)].filter(present)
    return lines.length ? join(lines.map((line) => html`<span class="tw:block">${line}</span>`)) : null
  }

  // Each size's wheelbase and its wheels' outer radii, as Sizes & geometry's overall length has them: the shortest and,
  // where it differs, the longest
  #totalLengths () {
    const lengths = array(this.data.sizes).map((size) => frameGeometry(this.data, size).wheels).filter(Boolean)
      .map((wheels) => this.presenter.rounded(sum(Object.values(wheels))))
    return lengths.length ? [...new Set([Math.min(...lengths), Math.max(...lengths)])] : []
  }

  // The max load, or without one the gross weight rating, with the other limits in its tooltip, or without either the
  // rider limit: in `size`, or its sizes' range
  #cargoWeight (size) {
    const { presenter } = this
    const { max_weight_total: maxLoad, gross_weight_rating: gross } = this.data.frame ?? {}
    const riders = (size ? [size] : array(this.data.sizes)).map((each) => each.geometry?.max_weight_rider).filter(isNumber)
    const riderLimit = () => join([`${this.kit.geometry.labels.max_weight_rider} `,
      join([...new Set([Math.min(...riders), Math.max(...riders)])].map((kg) => presenter.measurement(kg, 'kg')), '–')])
    const [limit, label, text] = isNumber(maxLoad) ? [maxLoad, 'Max load', MAX_LOAD] : [gross, 'Gross weight rating', GROSS_WEIGHT]
    if (!isNumber(limit)) return riders.length ? riderLimit() : null

    const cargo = this.data.cargo?.max_weight_cargo
    const lines = [isNumber(maxLoad) && isNumber(gross) && html`${GROSS_WEIGHT} ${presenter.measurement(gross, 'kg')}`,
      riders.some((kg) => kg !== limit) && riderLimit(),
      isNumber(cargo) && html`Max cargo weight ${presenter.measurement(cargo, 'kg')}`].filter(Boolean)
    const body = html`${text}${lines.map((line) => html`<span class="tw:block">${line}</span>`)}`
    return html`${label} ${presenter.measurement(limit, 'kg')} ${tooltip({ text, body })}`
  }

  // As /ebike-rules shows them: its US classes' tiles in order, an optional one's outlined, and an e-moto's, alone where
  // it's out of class as sold, and outlined in place of its optional throttle's where that would put it there, both with
  // that jurisdiction's ID. Without any, its classes' names
  #classTiles () {
    if (this.outOfClass === 'stock') return classBadges([`emoto/${this.outOfClassId}`])
    const ids = this.vehicle.classifiedModes.flatMap((mode) => mode.ids)
    const numbers = [...new Set(ids.map((id) => id.match(US_CLASS)?.[1]).filter(Boolean))].sort()
    const optional = this.#optionalClasses()
    const throttled = this.outOfClass === 'throttle'
    const classes = numbers.filter((number) => !(throttled && optional.get(number) === 'throttle'))
      .map((number) => optional.has(number) ? `${number}/${optional.get(number)}` : number)
    const tiles = [...classes, ...(this.#emoto(ids) ? ['emoto'] : throttled ? [`emoto/throttle/${this.outOfClassId}`] : [])]
    return tiles.length ? classBadges(tiles) : presence(this.classificationNames(this.#sortedClassifications(this.vehicle)))
  }

  // Its classes beside its /ebike-rules check
  eVehicleClass () {
    const classes = this.#classTiles()
    return classes && html`<div class="tw:flex tw:flex-wrap tw:items-end tw:gap-x-3 tw:gap-y-1"><div>${classes}</div><a class="twlink tw:text-sm"
      href=${`/ebike-rules?vehicle_models=${this.data.id}`}>View on e-bike rules</a></div>`
  }

  // As EbikeRuleServices::BikebookVehicles has them: the US classes only a mode it isn't sold with brings, by that mode,
  // and none when every class is
  #optionalClasses () {
    const numbers = (mode) => mode.ids.map((id) => id.match(US_CLASS)?.[1]).filter(Boolean)
    const modes = this.vehicle.classifiedModes
    const sold = new Set(modes.filter(stock).flatMap(numbers))
    if (!sold.size) return new Map()
    return new Map(modes.filter((mode) => !stock(mode)).flatMap((mode) => numbers(mode).filter((number) => !sold.has(number)).map((number) => [number, mode.mode])))
  }

  // As /ebike-rules has it (EbikeRuleServices::BikebookVehicles): a classification other than an e-bike law's or a US
  // class, or with neither, a mode over 28 mph
  #emoto (ids) {
    const tiers = ids.filter((id) => !this.presenter.vocabulary.e_vehicle_classifications[id]?.e_bike_law)
    if (tiers.length) return tiers.some((id) => !US_CLASS.test(id))
    const { km, mi } = this.kit.conversions.mm
    return Math.round(modes('max_speed')(this.data) * km / mi) > 28
  }

  #sortedClassifications (vehicle) {
    const names = (mode) => mode.ids.map((id) => this.presenter.classificationName(id))
    const standard = [...new Set(vehicle.classifiedModes.filter(stock).flatMap(names))].sort()
    const optional = [...new Map(vehicle.classifiedModes.filter((mode) => !stock(mode))
      .flatMap((mode) => names(mode).filter((name) => !standard.includes(name)).map((name) => [name, mode.mode])))]
    return { standard, optional }
  }

  yearRange () {
    const { first_year: first, final_year: final } = this.vehicle
    if (blank(first)) return null
    if (final === first) return String(first)
    return join([first, ' – ', presence(final) ?? 'current'])
  }

  specRows (key, fields = key === 'frame' ? this.kit.viewer.frame_fields : this.kit.schemas.vehicle[key].fields, labels = {}) {
    return this.presenter.rowsFor(fields, this.vehicle[key], {
      labels, others: this.others.map((other) => other[key]), collapse: ['bottom_bracket'], display: (value, field) => this.specValue(value, field)
    })
  }

  // `summary` of `item`, marked where the others' `counterparts` differ
  againstCounterparts (item, counterparts, summary) {
    const differs = counterparts.some((other) => !equal(other, item))
    return this.presenter.highlighted(summary(item), differs, differs && counterparts.map((other) => other && summary(other)))
  }

  specValue (value, key) {
    if (value == null) return value

    if (key === 'headset') return this.withTooltip(this.shisCode(value, 'tw:text-sm'), this.headsetTooltip(value))
    if (key === 'bottom_bracket') return this.bottomBracket(value)
    if (key === 'cable_routing') return this.tooltipped(value, this.kit.viewer.cable_routing_tooltips)
    if (key === 'coil_compatible') return value ? 'Yes' : 'No'
    if (key === 'front') return this.measurements(value, 'teeth', ', ')
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
    if (!last || (lastMarkup >= 0 && !head)) return html`<span class="keep-together tw:whitespace-nowrap">${content} ${tip}</span>`
    return join([...parts.slice(0, lastMarkup + 1), head ?? '', html`<span class="keep-together tw:whitespace-nowrap">${last} ${tip}</span>`])
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
      label: presenter.positionLabel(position),
      value: this.againstCounterparts(values, this.others.map((other) => other.suspension[position]), (each) => this.suspensionSummary(each))
    }))
    return section({ heading: 'Suspension', content: rows.length ? join(rows) : null })
  }

  frame () {
    return section({ heading: 'Frame', content: this.presenter.measurementRows(this.specRows('frame', undefined, FRAME_LABELS)) })
  }

  suspensionSummary (suspension) {
    const component = suspension.component
    const name = presence(component?.description?.split(',')[0].replace(/\s*\d+(\.\d+)?\s?mm$/i, ''))
    const { shock_length: length, shock_stroke: stroke, shock_mount: mount, spring, lockout } = suspension
    const size = truthy(length) ? this.measurements(compact([length, stroke]), 'mm', ' × ') : null
    const lead = this.travelLead(suspension)
    // an air spring is the usual one, so only coil is said
    const parts = compact([lead, presence(join(compact([size, name ?? (size ? 'shock' : null)]), ' ')), truthy(length) ? null : this.millimeters(stroke, ' stroke'),
      spring === 'coil' ? 'coil' : null, lockout ? 'lockout' : null])
    // an end with nothing stated is still suspended
    const summary = parts.length ? join(parts, ', ') : present(mount) ? `${upcaseFirst(mount)} shock mount` : html`<span class="twless-strong">Unknown travel</span>`
    const rows = this.suspensionRows(suspension)
    const shown = compact([lead ? 'travel' : null, 'shock_length', 'shock_stroke', parts.length ? null : 'shock_mount', spring === 'coil' ? 'spring' : null, lockout ? 'lockout' : null])
    const unshown = rows.some((row) => !shown.includes(row[4]) && !equal(row[1], name))
    return unshown ? this.withTooltip(summary, this.tooltipRows(rows)) : summary
  }

  // An end's specs and its fork's or shock's, as its tooltip lists them
  suspensionRows (suspension) {
    const { presenter } = this
    const component = suspension.component
    const dimensions = except(this.kit.schemas.component_dimensions, ['travel', 'extra_measurements'])
    const componentRows = component
      ? [[component.type_detail ?? component.type, component.description], ['Manufacturer', component.manufacturer], ...presenter.rowsFor(dimensions, component.dimensions)]
          .filter((row) => present(row[1]))
      : []
    return [...presenter.rowsFor(this.kit.viewer.suspension_fields, suspension, { labels: this.kit.viewer.suspension_labels, display: suspensionValue }), ...componentRows]
  }

  // "160 mm / 150 mm", or "60 mm front (no rear suspension)" for one end, with both ends' tooltips in one
  suspensionTravels () {
    const ends = this.vehicle.suspension
    if (blank(ends)) return html`<span class="twless-strong">Rigid</span>`

    const [front, rear] = ['front', 'rear'].map((position) => ends[position] && (this.travelLead(ends[position]) ?? 'unknown'))
    const travels = front && rear
      ? join([front, rear], ' / ')
      : front ? join([front, ' front (no rear suspension)']) : join([rear, ' rear (no front suspension)'])
    const body = join(Object.entries(ends).map(([position, end]) => html`<span class="tw:block tw:font-bold">${this.presenter.humanize(position)} suspension</span>${
      this.tooltipRows(this.suspensionRows(end))}`), html`<span class="tw:block tw:h-2"></span>`)
    return this.withTooltip(travels, body)
  }

  // travel can come from the fork or shock itself
  travelLead (suspension) {
    const travel = suspension.travel ?? suspension.component?.dimensions?.travel
    return truthy(travel) || suspension.size_travels.length ? this.travelSummary(travel, suspension.size_travels) : null
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
    return html`<code class="tw:rounded-sm tw:border tw:border-gray-200 tw:dark:border-gray-700 tw:px-1.5 tw:py-0.5 tw:font-mono tw:whitespace-nowrap ${size}">${code}</code>`
  }

  millimeters (value, suffix = null) {
    return truthy(value) ? join(compact([this.presenter.measurement(value, 'mm'), suffix])) : null
  }

  // As /ebike-rules shows a bike: its class tiles, its motor, top assisted speed and throttle, and its certifications
  electricSummary () {
    const { presenter, vehicle } = this
    if (blank(vehicle.motors)) return nothing

    const of = (kind) => vehicle.classifiedModes.filter(({ mode }) => mode === kind)
    const fastest = (modes) => {
      const speed = highest(modes.map(({ maxSpeed }) => maxSpeed))
      return speed == null ? null : presenter.measurement(speed, 'km/h')
    }
    const throttles = of('throttle')
    const throttleSpeed = fastest(throttles)
    const throttle = throttles.length ? join([throttles.some(stock) ? 'Yes' : 'Optional', ...(throttleSpeed ? [', to ', throttleSpeed] : [])]) : 'No'
    const rated = array(vehicle.motors).map((motor) => motor.rated_power).filter(isNumber)
    const specs = [['Motor', rated.length ? presenter.measurement(sum(rated), 'w') : null], ['Top speed', fastest(of('assist'))], ['Throttle', throttle]]
    const certifications = certificationsOf(array(vehicle.motors).map((motor) => motor.certification))
    return html`<div class="tw:mb-6">${bikeSummary({ vehicleType: this.data.type, tiles: this.eVehicleClass(), specs, ...certifications })}</div>`
  }

  // One per motor index across the compared vehicles, motors alike but for their drive wheel as one
  motorSections () {
    const [motors, ...othersMotors] = [this.vehicle, ...this.others].map((vehicle) => mergedMotors(vehicle.motors ?? []))
    const count = Math.max(motors.length, ...othersMotors.map((each) => each.length))
    return Array.from({ length: count }, (_, index) => {
      const motor = motors[index]
      const wheels = array(motor?.drive_wheel).map((wheel) => this.presenter.humanize(wheel))
      const heading = wheels.length > 1
        ? `${andSentence(wheels)} Motor`
        : count === 1 ? 'Motor & Battery' : wheels.length ? `${wheels[0]} motor` : `Motor ${index + 1}`
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
      content: join(this.vehicle[key].map((item) => definitionListRow({
        label: presenter.positionLabel(item.position) ?? fallback,
        content: this.againstCounterparts(item, this.others.map((other) => this.byPosition(other[key], item.position)), summary)
      })))
    })
  }

  builtWheels (vehicle = this.vehicle) {
    return array(vehicle.wheels).filter((wheel) => wheel.configured !== false)
  }

  // `size`'s wheels as [label, content], each its size, labelled as Wheels labels it, over its tire: front and rear as one
  // where they're the same size and tire
  sizeWheels (size) {
    const [front, rear] = ['front', 'rear'].map((position) => at(this.builtWheels(), position, size)[0])
    const rows = (wheelLabel, tireLabel, wheel) => {
      const tire = compact([wheel.tire_width != null ? this.tireWidthSummary(wheel.tire_width, '') : null, wheel.tire_system?.replaceAll('_', ' ')])
      return [[wheelLabel, wheel.bsd != null ? this.wheelSizeName(wheel.bsd) : null], [tireLabel, tire.length ? join(tire, ', ') : null]]
        .filter(([, content]) => content != null)
    }
    const fitted = (wheel) => slice(wheel, ['bsd', 'tire_width', 'tire_system'])
    const label = this.presenter.positionLabel.bind(this.presenter)
    if (front && rear && equal(fitted(front), fitted(rear))) return rows(label(['front', 'rear']), 'Tires', front)
    return [['front', front], ['rear', rear]].filter(([, wheel]) => wheel).flatMap(([position, wheel]) => rows(label(position), `${label(position)} tire`, wheel))
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

    const rows = this.builtWheels().map((wheel) => definitionListRow({
      label: presenter.positionLabel(wheel.position) ?? 'Wheel',
      content: this.againstCounterparts(wheel, this.others.map((other) => this.byPosition(this.builtWheels(other), wheel.position)), (each) => this.wheelSummary(each))
    }))
    const clearances = this.clearances()
    const alsoFits = clearances.length
      ? definitionListRow({
        label: 'Also fits',
        content: this.againstCounterparts(clearances, this.others.map((other) => this.clearances(other)), (each) => this.clearanceSummary(each))
      })
      : nothing
    return section({ heading: 'Wheels', content: join([...rows, alsoFits]) })
  }

  clearanceSummary (clearances) {
    const built = [...new Set(this.builtWheels().flatMap((wheel) => array(wheel.position)))].sort()
    return join(clearances.map(([bsd, max, positions]) => {
      const wheel = join(compact([bsd ? this.wheelSizeName(bsd) : null, equal(positions, built) ? null : `on the ${this.presenter.positionLabel(positions).toLowerCase()}`]), ' ')
      return join(compact([presence(wheel), max ? this.tireWidthSummary(max, 'tire max') : null]), ', ')
    }), '; ')
  }

  // `fitting`: how the wheel fits the frame, its cassette, dropout and axle
  wheelSummary (wheel, { fitting = true } = {}) {
    const summary = join(this.wheelParts(wheel, { fitting }).map(([, content]) => content), ', ')
    return wheel.max_tire_width != null ? join([summary, this.tireWidthSummary(wheel.max_tire_width, 'tire max')], html`<br>`) : summary
  }

  wheelParts (wheel, { fitting = true } = {}) {
    return [
      ['size', this.onSizes(wheel.bsd != null ? this.wheelSizeName(wheel.bsd) : null, wheel.sizes)],
      ['tire', wheel.tire_width != null ? this.tireWidthSummary(wheel.tire_width) : null],
      ['tire_system', wheel.tire_system?.replaceAll('_', ' ')],
      ...(fitting
        ? [['cassette', wheel.cassette_interface != null ? `${wheel.cassette_interface} cassette` : null],
            ['dropout', wheel.dropout != null ? `${wheel.dropout.replaceAll('_', ' ')} dropout` : null], ['axle', this.axleSummary(wheel)]]
        : [])
    ].filter(([, content]) => content != null)
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
    const suffix = label ? ` ${label}` : ''
    if (tireWidth <= WIDE_TIRE) return join([presenter.measurement(tireWidth, 'mm'), suffix])

    return this.keepTogether(join([tireInches(presenter, tireWidth), suffix]), tooltip({ text: `${tireWidth} mm` }))
  }

  // "700 C × 40 mm", or "700 C × 40 mm front, 650 B × 47 mm rear", over the widest tire they take
  wheelSizes () {
    const [front, rear] = ['front', 'rear'].map((position) => new Map(this.builtWheels()
      .filter((wheel) => wheel.bsd && array(wheel.position).includes(position)).map((wheel) => [`${wheel.bsd}/${wheel.tire_width}`, wheel])))
    const names = (wheels) => join([...wheels.values()].map((wheel) =>
      join(compact([this.wheelSizeName(wheel.bsd), wheel.tire_width != null ? this.tireWidthSummary(wheel.tire_width, '') : null]), ' × ')), ' / ')
    const sizes = equal([...front.keys()], [...rear.keys()])
      ? (front.size ? names(front) : null)
      : join(compact([front.size ? join([names(front), ' front']) : null, rear.size ? join([names(rear), ' rear']) : null]), ', ')
    const tireMax = this.tireMax()
    return tireMax ? join(compact([sizes, tireMax]), html`<br>`) : sizes
  }

  // "2.4 in tire max", or "2.4 in front, 2.6 in rear tire max"
  tireMax () {
    const [front, rear] = ['front', 'rear'].map((position) =>
      highest(this.builtWheels().filter((wheel) => array(wheel.position).includes(position)).map((wheel) => wheel.max_tire_width)))
    if (front === rear) return front == null ? null : this.tireWidthSummary(front, 'tire max')

    const widths = compact([front != null ? join([this.tireWidthSummary(front, ''), ' front']) : null, rear != null ? join([this.tireWidthSummary(rear, ''), ' rear']) : null])
    return join([join(widths, ', '), ' tire max'])
  }

  wheelSizeName (bsd) {
    const size = this.presenter.vocabulary.wheel_sizes[bsd]
    if (!size) return join([this.presenter.measurement(bsd, 'mm'), ' BSD'])
    if (size.standard) return size.name
    return this.keepTogether(size.name, tooltip({ body: join(compact([presence(size.description), `${bsd} mm BSD`]).map((line) => html`<span class="tw:block">${line}</span>`)) }))
  }

  brakeSummary (brake) {
    const typeAndRotor = presence(join(compact([brakeType(brake), this.millimeters(brake.rotor_diameter, ' rotor')]), ', '))
    const summary = join(compact([this.onSizes(typeAndRotor, brake.sizes), presence(brake.caliper_mount?.replace(/^Disc /, '')), brake.anti_lock ? 'ABS' : null]), ', ')
    return brake.max_rotor_diameter != null ? join([summary, this.millimeters(brake.max_rotor_diameter, ' rotor max')], html`<br>`) : summary
  }

  drivetrain () {
    const { presenter, vehicle } = this
    // a compared model's values give this one rows it has nothing for
    const content = presenter.measurementRows([...this.groupsetRows(), ...this.gearingRows()])
    if (blank(vehicle.drivetrain) && blank(content)) return nothing

    const othersLabels = this.others.map((other) => drivetrainLabels(other.drivetrain))
    const differs = (label) => othersLabels.some((labels) => !labels.includes(label))
    return html`<section class="tw:mb-6 tw:break-inside-avoid tw:space-y-2"><h2 class="tw:text-xs tw:font-bold tw:tracking-wider tw:text-[#715eb2] tw:uppercase">Drivetrain</h2>${present(vehicle.drivetrain)
      ? html`<div class="tw:flex tw:flex-wrap tw:gap-2">${drivetrainLabels(vehicle.drivetrain).map((label) => html`<span class="tw:rounded-sm tw:border tw:border-gray-200 tw:dark:border-gray-700 ${differs(label)
        ? 'tw:spec-diff'
        : 'tw:bg-white tw:dark:bg-gray-800'} tw:px-2 tw:py-0.5 tw:font-mono
        tw:text-xs">${this.tooltipped(label, this.kit.viewer.drivetrain_tooltips)}</span>`)}</div>`
      : nothing}${present(content) ? definitionListContainer({ content }) : nothing}</section>`
  }

  // "MicroShift, 1x9", the rest of its drivetrain in a tooltip, on a dash where neither is listed
  groupsetWithDrivetrain () {
    const groupset = presence(join([groupsetSummary(this.vehicle), this.#gearCount()].filter(present), ', '))
    const drivetrain = this.drivetrainTooltip()
    return drivetrain ? this.withTooltip(groupset ?? missing, drivetrain) : groupset
  }

  // Its chainrings by its cogs, "1x9", or "singlespeed" for one of each
  #gearCount () {
    const count = (pattern) => array(this.data.drivetrain).map((each) => String(each).match(pattern)?.[1]).find(Boolean)
    const [front, rear] = [/^(\d+)_front$/, /^(\d+)_(?:internal_)?rear$/].map(count)
    if (!front || !rear) return null
    return front === '1' && rear === '1' ? 'singlespeed' : `${front}x${rear}`
  }

  gearingRows () {
    const fields = slice(this.kit.schemas.vehicle.frame.fields, this.kit.viewer.drivetrain_frame_fields)
    const counted = Object.fromEntries(Object.entries(this.kit.viewer.gearing_labels)
      .map(([position, label]) => [position, array(this.vehicle.gearing?.[position]).length === 1 ? label : `${label}s`]))
    return [...this.specRows('gearing', this.kit.schemas.vehicle.gearing.fields, counted), ...this.specRows('frame', fields)]
  }

  // the Drivetrain section's rows but the groupset, as a tooltip lists them
  drivetrainTooltip () {
    const labels = drivetrainLabels(this.vehicle.drivetrain)
    const rows = [...(labels.length ? [['Drivetrain', labels.join(', ')]] : []), ...this.gearingRows()]
    return rows.length ? this.tooltipRows(rows) : null
  }

  // a list, so against a model that isn't electronic, that alone is marked
  groupsetRows () {
    const { vehicle, others } = this
    if ([vehicle, ...others].every(({ groupset }) => blank(groupset))) return []
    return [['Groupset', groupsetSummary(vehicle), null, others.some((other) => !equal(other.groupset, vehicle.groupset)), 'groupset', others.map(groupsetSummary)]]
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

  sizesDisclosure () {
    const sizes = this.vehicle.sizes
    if (blank(sizes)) return nothing

    return disclosure({
      param: 'sizes',
      label: 'sizes',
      heading: html`Sizes & geometry <span class="tw:ml-1 tw:font-mono tw:text-sm tw:font-normal tw:tracking-normal tw:opacity-65 tw:normal-case">${numberDisplay(sizes.length)}</span>`,
      content: html`<div data-ui--collapse-target="content" class="tw:-mx-(--gutter)">${this.sizes()}</div>`
    })
  }

  sizes () {
    const sizes = this.vehicle.sizes
    if (blank(sizes)) return nothing

    const others = this.others.map((other) => other.sizes)
    // padded inside the scroller, so its cards scroll out to the edges of the card it bleeds across, which scrolls to the
    // selected one as ui--tabs does its active tab
    return html`<div data-controller="ui--tabs" class="tw:overflow-x-auto tw:px-(--gutter) tw:pb-3.5"><div data-ui--tabs-target="row"
      class="tw:flex tw:w-max tw:min-w-full tw:gap-4">${sizes.map((size) => geometryCard({
        presenter: this.presenter,
        size,
        others,
        selected: present(this.selectedSize) && size.name === this.selectedSize,
        href: this.sizePath?.(size.name),
        ...this.lettering,
        wheels: this.sizeWheels(size),
        cargo: this.vehicle.cargo,
        otherCargos: this.others.map((other) => other.cargo)
      }))}</div></div>`
  }

  // Each component group's rows across `vehicles`, a cell per vehicle, those matching across them first, then those
  // more of them have, then in order of the first cell's type
  componentRows (vehicles) {
    const groups = Object.keys(this.kit.component_groups)
    const group = (type) => this.presenter.componentGroups.get(type) ?? groups.at(-1)
    const label = (row) => typeLabel(row.find(Boolean)).toLowerCase()
    const had = (row) => row.filter(Boolean).length
    return groups.map((name) => [name, pairedComponents(vehicles.map((vehicle) => array(vehicle.components).filter((component) => group(component.type) === name)))
      .sort((a, b) => matchingRow(b) - matchingRow(a) || had(b) - had(a) || (label(a) < label(b) ? -1 : label(a) > label(b) ? 1 : 0))])
  }

  // Its cells of the `groups`' rows, at `index`, marked against the `compared` cells. Given a `layout`, every row,
  // blank where only those have one, so it lines up with the other cards
  components (layout) {
    if (blank(this.vehicle.components)) return nothing

    const { groups, index, compared } = layout ??
      { groups: this.componentRows([this.vehicle, ...this.others]), index: 0, compared: this.others.map((_, at) => at + 1) }
    return groups.flatMap(([name, rows]) => {
      const shown = layout ? rows : rows.filter((row) => row[index])
      if (shown.length === 0) return []

      return [componentGroup({
        presenter: this.presenter,
        name,
        rows: shown.map((row) => ({ component: row[index], counterparts: compared.map((at) => row[at]) })),
        alignKey: layout && name
      })]
    })
  }
}

// to_sentence: "Front, Middle and Rear"
// Motors that match but for their drive wheel, as one listing each drive wheel
const mergedMotors = (motors) => motors.reduce((merged, motor) => {
  const index = merged.findIndex((each) => equal(except(each, ['drive_wheel']), except(motor, ['drive_wheel'])))
  return index < 0
    ? [...merged, motor]
    : merged.map((each, at) => at === index ? { ...each, drive_wheel: [...array(each.drive_wheel), ...array(motor.drive_wheel)] } : each)
}, [])

// simple_format
export const simpleFormat = (text) => String(text).replace(/\r\n?/g, '\n').split(/\n\n+/).map((paragraph) => {
  const lines = paragraph.split('\n')
  return html`<p>${lines.map((line, index) => index === 0 ? line : ['\n', lines[index - 1] && line ? html`<br>` : nothing, line])}</p>`
})
