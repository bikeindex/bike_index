// How alike catalog models are, from the values the catalog publishes as `comparison`. The weights, scales and
// presets are ours; the values are worked out by bikebook's Catalog::Comparison, so none is derived again here but
// the rider heights a size doesn't state.
// Imported by the catalog's worker too, which has no importmap, so it imports nothing

const FORMAT = 2
const COUNT = 12
export const MAX_WEIGHT = 5

// a distance in scales, past which one outlying field can't count for more
const CAP = 3
// a categorical field that differs
const MISMATCH = 2
// a field the candidate doesn't list, so listing less never looks closer
const UNLISTED = 1
// the score a candidate has to beat to show, short of an unlisted field's, as a thin pool's last are otherwise its leftovers
const MAX_SCORE = 0.8
// of the weight the model has values for, what a candidate has to share, or one listing almost nothing matches everything
const MIN_SHARED = 0.4
// an activity family with fewer values than this is scaled by the whole catalog's
const MIN_FAMILY_VALUES = 30
const FIXED_SCALES = { first_year: 2, groupset: 1, rider_height: 60 }

// in mm, the riders' heights between which every model comes in a size that fits: 5′5″ and 6′2″
const SHORT = 1650
const TALL = 1880
// the span of riders' heights a size fits, where it states only one end or neither
const SPAN = 100
// a family with fewer sizes stating their riders than this estimates no others'
const MIN_FIT_SIZES = 100

// more than the model's as far as this much of the same less is, as a roomier frame still fits its tires
const ROOMIER = 0.75

// the kinds whose same is a match rather than a nearness, which a slider at its top requires
const REQUIRABLE = ['same', 'set', 'year', 'fit']
// the kinds measured in their field's scales
const SCALED = ['numeric', 'year', 'roomier', 'fit']

const complete = ({ model_configuration: configuration }) => configuration === 'complete'
const numeric = (a, b, scale) => a === b ? 0 : Math.min(CAP, Math.abs(a - b) / scale)

// Each kind's distance between two values, both present, in its field's scales
const KINDS = {
  numeric,
  // a numeric whose same is a match, as a model's first year is
  year: numeric,
  roomier: (a, b, scale) => numeric(a, b, scale) * (b > a ? ROOMIER : 1),
  // a rider's height from the heights a model's sizes fit, [shortest, tallest]
  fit: (height, [shortest, tallest], scale) => Math.min(CAP, Math.max(0, shortest - height, height - tallest) / scale),
  same: (a, b) => a === b ? 0 : MISMATCH,
  set: (a, b) => a.length === b.length && a.every((value) => b.includes(value)) ? 0 : MISMATCH,
  overlap: (a, b) => MISMATCH * (1 - a.filter((value) => b.includes(value)).length / new Set([...a, ...b]).size)
}

// Each slider's fields, each of `kind`, and what its top end matches where that isn't its label; battery size and price
// are compared by their logs, so twice the price is as far at any price. A field's `shares` of its slider's weight are 1
// unless it says otherwise, and `separate` fields measure different things, so their slider's weight grows by the root of
// how many the model lists. `unlisted` says why a model has none of a slider's values
export const GROUPS = {
  handlebar: { label: 'Handlebar type', fields: { handlebar_type: 'same' } },
  geometry: { label: 'Geometry', separate: true, shares: { head_angle: 3 }, fields: { head_angle: 'numeric', seat_angle: 'numeric', stack_reach: 'numeric', bb_drop: 'numeric', chainstay_gap: 'numeric' } },
  fit: { label: 'Rider size', unlisted: 'Only for sizes fitting riders under 5′5″ or over 6′2″', fields: { rider_height: 'fit' } },
  // a kids' bike unlike any other, a women's or adaptive one only a little
  riders: { label: 'Target riders', shares: { kid: 3 }, fields: { kid: 'same', target_riders: 'set' } },
  tires: { label: 'Tire clearance', fields: { tire_clearance: 'roomier' } },
  suspension: { label: 'Suspension', same: 'suspension travel', fields: { travel_front: 'numeric', travel_rear: 'numeric', suspension: 'same' } },
  ebike: { label: 'E-vehicle motor and battery', same: 'motor and battery attributes', fields: { modes: 'set', assist_speed: 'numeric', throttle_speed: 'numeric', battery_size: 'numeric', motor_kind: 'same' } },
  groupset: { label: 'Groupset', fields: { groupset: 'numeric' } },
  price: { label: 'Price', fields: { price: 'numeric' } },
  material: { label: 'Frame material', fields: { frame_material: 'same' } },
  weight: { label: 'Weight', fields: { total_weight: 'numeric' } },
  mounts: { label: 'Mounts (e.g. fender, rack, bottles)', same: 'mounts', fields: { mounts: 'overlap', bottle_mounts: 'numeric' } },
  year: { label: 'Year', fields: { first_year: 'year' } },
  activity: { label: 'Primary activity', fields: { primary_activity: 'same' } }
}

// weight low by default, as much of it is what the others weigh already
const GENERAL = { handlebar: 5, geometry: 4, fit: 4, riders: 3, tires: 4, suspension: 3, ebike: 3, groupset: 2, price: 2, material: 2, weight: 1, mounts: 1, year: 1, activity: 1 }
export const PRESETS = {
  general: { label: 'Default weights', weights: GENERAL }
}

// The preset whose weights `weights` are in each of `groups`, or custom
export const presetOf = (weights, groups) => Object.keys(PRESETS).find((key) => groups.every((group) => PRESETS[key].weights[group] === weights[group])) ?? 'custom'

// `weights=geometry.5,price.0`, each slider differing from the default weights
export const weightsFrom = (param) => {
  const set = Object.fromEntries(String(param ?? '').split(',').map((pair) => pair.split('.'))
    .filter(([group, weight]) => group in GROUPS && /^\d+$/.test(weight)).map(([group, weight]) => [group, Math.min(MAX_WEIGHT, Number(weight))]))
  return { ...GENERAL, ...set }
}

// The URL's weights, whether skip_manufacturer=1 leaves out the model's maker's others, whether other_propulsion=1
// matches only those electric where it isn't, or human powered where it's electric, whether same_configuration=1
// matches only complete models where it's complete, or frames and framesets where it isn't, whether same_wheels=1
// matches only its wheel sizes, and whether different_types=1 includes other vehicle types; and the rider's `size`, by
// its index in the model's sizes
export const settingsFrom = (params, size) => ({
  weights: weightsFrom(params.get('weights')),
  skipManufacturer: params.get('skip_manufacturer') === '1',
  otherPropulsion: params.get('other_propulsion') === '1',
  sameConfiguration: params.get('same_configuration') === '1',
  sameWheels: params.get('same_wheels') === '1',
  differentTypes: params.get('different_types') === '1',
  size
})

export const weightsParam = (weights) => Object.keys(GROUPS).filter((group) => weights[group] !== GENERAL[group])
  .map((group) => `${group}.${weights[group]}`).join(',')

// Each tier's series, lowest first, so Rival ≈ 105 ≈ GRX 600; named without the words makers add to a series
const TIERS = Object.fromEntries([
  ['2200', 'tourney', 'acolyte'],
  ['x3', 'x4', 'altus', 'acera', 'claris', '2300', 'nexus'],
  ['alivio', 'sora', 'cues', 'sx', 'x5', 'advent', 'mezzo'],
  ['tiagra', 'deore', 'nx', 'apex', 'x7', 'alfine', 'veloce', 'grx 400', 'grx 410', 'advent x', 'sword'],
  ['105', 'rival', 'slx', 'gx', 'x9', 'x1', 'zee', 'deore lx', 'metrea', 'grx', 'grx 600', 'grx 610', 'centaur', 'potenza', 'ekar gt', 'eagle 70', 's1000', 's 1000'],
  ['ultegra', 'force', 'xt', 'deore xt', 'x01', 'x0', 'saint', 'grx 800', 'grx 810', 'grx 820', 'chorus', 'athena', 'ekar', 'eagle 90'],
  ['dura ace', 'red', 'xtr', 'xx1', 'xx', 'xx sl', 'record', 'super record']
].flatMap((names, tier) => names.map((name) => [name, tier])))
const SERIES_WORDS = /\b(shimano|sram|campagnolo|microshift|eagle(?! [79]0)|axs|di2|etap|transmission|t type|xplr|wide|mullet|\d+ ?(speed|s|x))\b/g
const unmapped = new Set()
const tier = (name) => {
  if (name == null) return null
  const key = name.toLowerCase().replace(/[^a-z0-9]+/g, ' ').replace(SERIES_WORDS, ' ').replace(/\s+/g, ' ').trim()
  if (key in TIERS) return TIERS[key]
  // parsers add spellings, which the table then has to
  if (!unmapped.has(name)) console.warn(`BikeBook: no groupset tier for "${name}"`)
  unmapped.add(name)
  return null
}

const quantile = (sorted, fraction) => {
  const position = (sorted.length - 1) * fraction
  const below = Math.floor(position)
  return sorted[below] + (sorted[Math.ceil(position)] - sorted[below]) * (position - below)
}
const iqr = (values) => {
  const sorted = [...values].sort((a, b) => a - b)
  return quantile(sorted, 0.75) - quantile(sorted, 0.25)
}
const log = (value) => value > 0 ? Math.log(value) : null
const mean = (values) => values.reduce((sum, value) => sum + value, 0) / values.length
// the least squares line through `points`, [x, y]
const line = (points) => {
  const [meanX, meanY] = [0, 1].map((axis) => mean(points.map((point) => point[axis])))
  const slope = mean(points.map(([x, y]) => (x - meanX) * (y - meanY))) / mean(points.map(([x]) => (x - meanX) ** 2))
  return (x) => meanY + slope * (x - meanX)
}
// each group's line through its [group, x, y] `points`, of the groups with enough of them
const groupLines = (points) => {
  const groups = new Map()
  for (const [group, ...point] of points) groups.get(group)?.push(point) ?? groups.set(group, [point])
  return new Map([...groups].filter(([, each]) => each.length >= MIN_FIT_SIZES).map(([group, each]) => [group, line(each)]))
}
const middle = ([min, max]) => (min + max) / 2

// Scores the catalog's `models`, in the index's order, which the comparison's columns are in. Null for a format it
// doesn't know
export const scorer = (models, { format, fields }, activities) => {
  if (format !== FORMAT) return null

  const familyBySlug = new Map(activities.map(({ slug, family }) => [slug, family]))
  const families = models.map((model) => familyBySlug.get(model.primary_activity) ?? null)
  const attribute = (key) => models.map((model) => model[key] ?? null)
  // a field a catalog published before bikebook added it lacks
  const unpublished = models.map(() => null)
  const riders = fields.target_riders?.map((each) => each ?? [])
  const kids = riders?.map((each) => each.includes('kid')) ?? unpublished

  // Each size's riders' heights, [shortest, tallest], as it states them, else about the line through the middles of
  // those its family's sizes state, by its stack plus reach, as a mountain bike's frame is longer than a road bike's for
  // the same rider, or a kids' by its wheel size
  const sizeValue = (field, index, size) => fields[field]?.[index]?.[size] ?? null
  const statedHeights = (index, size) => {
    const [min, max] = ['size_min_rider_height', 'size_max_rider_height'].map((field) => sizeValue(field, index, size))
    return min == null && max == null ? null : [min ?? max - SPAN, max ?? min + SPAN]
  }
  const measureOf = (index, size) => {
    if (kids[index]) return fields.front_bsd[index]
    const [stack, reach] = ['size_stack', 'size_reach'].map((field) => sizeValue(field, index, size))
    return stack == null || reach == null ? null : stack + reach
  }
  const fitFamily = (index) => kids[index] ? 'kid' : families[index]
  const sizes = models.map((_, index) => Array.from({ length: fields.size_names?.[index]?.length ?? 0 },
    (_, size) => [statedHeights(index, size), measureOf(index, size)]))
  const lines = groupLines(sizes.flatMap((each, index) => each.filter(([stated, measure]) => stated && measure != null)
    .map(([stated, measure]) => [fitFamily(index), measure, middle(stated)])))
  const heights = sizes.map((each, index) => each.map(([stated, measure]) => {
    const estimate = measure != null && lines.get(fitFamily(index))?.(measure)
    return stated ?? (estimate ? [estimate - SPAN / 2, estimate + SPAN / 2] : null)
  }))

  const columns = {
    ...fields,
    battery_size: fields.battery_size.map(log),
    groupset: fields.groupset_series.map(tier),
    suspension: attribute('suspension'),
    handlebar_type: attribute('handlebar_type'),
    primary_activity: attribute('primary_activity'),
    // its first, as one still sold isn't as new as it is current
    first_year: attribute('first_year'),
    price: models.map((model) => log(model.msrp_cents)),
    frame_material: fields.frame_material ?? unpublished,
    kid: kids,
    target_riders: riders?.map((each) => each.filter((rider) => rider !== 'kid')) ?? unpublished,
    rider_height: heights.map((each) => {
      const known = each.filter(Boolean)
      return known.length ? [Math.min(...known.map(([min]) => min)), Math.max(...known.map(([, max]) => max))] : null
    })
  }
  const indexes = new Map(models.map((model, index) => [model.id, index]))

  // each numeric field's interquartile range in a family, or in the catalog where the family has too few values
  const scales = new Map()
  const scaleOf = (field, family) => {
    if (field in FIXED_SCALES) return FIXED_SCALES[field]
    const key = `${field}/${family}`
    if (!scales.has(key)) {
      const values = columns[field].filter((value, index) => value != null && families[index] === family)
      scales.set(key, values.length >= MIN_FAMILY_VALUES ? iqr(values) : iqr(columns[field].filter((value) => value != null)))
    }
    return scales.get(key)
  }

  // The `COUNT` models most like the one `id` names by `weights`, narrowed as settingsFrom's settings say, each the
  // closest of its model group and never of its own; and the sliders whose fields it has values for. `otherPropulsion`
  // leaves its e-bike fields unscored, and `sameWheels` requires only the wheels it lists. Its sizes' index `size` is
  // the rider's, whose fit is scored only where it's shorter or taller than any model fits
  return (id, { weights, skipManufacturer, otherPropulsion, sameConfiguration, sameWheels, differentTypes, size }) => {
    const target = indexes.get(id)
    if (target == null) return null

    const model = models[target]
    const family = families[target]
    const range = heights[target][size]
    const height = range && middle(range)
    const own = {
      ...Object.fromEntries(Object.keys(columns).map((field) => [field, columns[field][target]])),
      rider_height: height && (height < SHORT || height > TALL) ? height : null
    }
    // each slider's weight shared among the fields the model lists, so a rigid bike, listing no travel, counts its suspension in full
    const listed = Object.entries(GROUPS).flatMap(([group, { fields, separate, shares = {} }]) => {
      const present = Object.entries(fields).filter(([field]) => own[field] != null)
      const divisor = present.reduce((sum, [field]) => sum + (shares[field] ?? 1), 0) / (separate ? Math.sqrt(present.length) : 1)
      return present.map(([field, kind]) => ({
        group,
        field,
        kind,
        scale: SCALED.includes(kind) ? scaleOf(field, family) : null,
        weight: (weights[group] ?? 0) * (shares[field] ?? 1) / divisor
      }))
    })
    const groups = [...new Set(listed.map(({ group }) => group))]
    const weighted = listed.filter(({ group, weight }) => weight > 0 && !(otherPropulsion && group === 'ebike'))
    const available = weighted.reduce((total, { weight }) => total + weight, 0)
    const required = [...weighted.filter(({ group, kind }) => weights[group] === MAX_WEIGHT && REQUIRABLE.includes(kind)),
      ...(sameWheels ? ['front_bsd', 'rear_bsd'].filter((field) => own[field] != null).map((field) => ({ field, kind: 'same' })) : [])]
    if (!available) return { groups, models: [] }

    const scored = []
    models.forEach((candidate, index) => {
      if (index === target || candidate.group_key === model.group_key || (candidate.electric === model.electric) === otherPropulsion ||
        (!differentTypes && candidate.vehicle_type !== model.vehicle_type) ||
        (sameConfiguration && complete(candidate) !== complete(model)) ||
        (skipManufacturer && candidate.manufacturer === model.manufacturer) ||
        required.some(({ field, kind, scale }) => columns[field][index] == null || KINDS[kind](own[field], columns[field][index], scale) > 0)) return

      let shared = 0
      let total = 0
      for (const { field, kind, scale, weight } of weighted) {
        const value = columns[field][index]
        // a frame's weight isn't a whole bike's
        if (value == null || (field === 'price' && candidate.msrp_currency !== model.msrp_currency) ||
          (field === 'total_weight' && complete(candidate) !== complete(model))) continue
        shared += weight
        total += weight * KINDS[kind](own[field], value, scale)
      }
      const score = (total + (available - shared) * UNLISTED) / available
      if (shared >= MIN_SHARED * available && score < MAX_SCORE) scored.push({ index, score })
    })
    const grouped = new Set()
    const closest = scored.sort((a, b) => a.score - b.score)
      .filter(({ index }) => !grouped.has(models[index].group_key) && grouped.add(models[index].group_key))
    return { groups, models: closest.slice(0, COUNT).map(({ index }) => models[index]) }
  }
}
