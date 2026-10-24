// How alike catalog models are, from the values the catalog publishes as `comparison`. The weights, scales and
// presets are ours; the values are worked out by bikebook's Catalog::Comparison, so none is derived again here.
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
const FIXED_SCALES = { first_year: 2, groupset: 1 }

// the kinds whose same is a match rather than a nearness, which a slider at its top requires
const REQUIRABLE = ['same', 'set', 'year']

const numeric = (a, b, scale) => a === b ? 0 : Math.min(CAP, Math.abs(a - b) / scale)

// Each kind's distance between two values, both present, in its field's scales
const KINDS = {
  numeric,
  // a numeric whose same is a match, as a model's first year is
  year: numeric,
  same: (a, b) => a === b ? 0 : MISMATCH,
  set: (a, b) => a.length === b.length && a.every((value) => b.includes(value)) ? 0 : MISMATCH,
  overlap: (a, b) => MISMATCH * (1 - a.filter((value) => b.includes(value)).length / new Set([...a, ...b]).size)
}

// Each slider's fields, each of `kind`, and what its top end matches where that isn't its label; battery size and price
// are compared by their logs, so twice the price is as far at any price
export const GROUPS = {
  handlebar: { label: 'Handlebar type', fields: { handlebar_type: 'same' } },
  geometry: { label: 'Geometry', fields: { head_angle: 'numeric', seat_angle: 'numeric', stack_reach: 'numeric', bb_drop: 'numeric', chainstay_gap: 'numeric' } },
  tires: { label: 'Tire clearance', fields: { tire_clearance: 'numeric' } },
  suspension: { label: 'Suspension', same: 'suspension travel', fields: { travel_front: 'numeric', travel_rear: 'numeric', suspension: 'same' } },
  ebike: { label: 'E-vehicle motor and battery', same: 'motor and battery attributes', fields: { modes: 'set', assist_speed: 'numeric', throttle_speed: 'numeric', battery_size: 'numeric', motor_kind: 'same' } },
  groupset: { label: 'Groupset', fields: { groupset: 'numeric' } },
  year: { label: 'Year', fields: { first_year: 'year' } },
  material: { label: 'Frame material', fields: { frame_material: 'same' } },
  weight: { label: 'Weight', fields: { total_weight: 'numeric' } },
  mounts: { label: 'Mounts', fields: { mounts: 'overlap', bottle_mounts: 'numeric' } },
  price: { label: 'Price', fields: { price: 'numeric' } },
  activity: { label: 'Primary activity', fields: { primary_activity: 'same' } }
}

// price low by default, as a tiebreaker, and weight, as much of it is what the others weigh already
const GENERAL = { handlebar: 5, geometry: 4, tires: 4, suspension: 3, ebike: 3, groupset: 2, year: 2, material: 2, weight: 1, mounts: 1, price: 1, activity: 1 }
export const PRESETS = {
  general: { label: 'General', weights: GENERAL }
}

// The preset whose weights `weights` are in each of `groups`, or custom
export const presetOf = (weights, groups) => Object.keys(PRESETS).find((key) => groups.every((group) => PRESETS[key].weights[group] === weights[group])) ?? 'custom'

// `weights=geometry.5,price.0`, each slider differing from General's
export const weightsFrom = (param) => {
  const set = Object.fromEntries(String(param ?? '').split(',').map((pair) => pair.split('.'))
    .filter(([group, weight]) => group in GROUPS && /^\d+$/.test(weight)).map(([group, weight]) => [group, Math.min(MAX_WEIGHT, Number(weight))]))
  return { ...GENERAL, ...set }
}

// The URL's weights, whether skip_manufacturer=1 leaves out the model's maker's others, whether other_propulsion=1
// matches only those electric where it isn't, or human powered where it's electric, whether same_configuration=1
// matches only complete models where it's complete, or frames and framesets where it isn't, whether same_wheels=1
// matches only its wheel sizes, and whether different_types=1 includes other vehicle types
export const settingsFrom = (params) => ({
  weights: weightsFrom(params.get('weights')),
  skipManufacturer: params.get('skip_manufacturer') === '1',
  otherPropulsion: params.get('other_propulsion') === '1',
  sameConfiguration: params.get('same_configuration') === '1',
  sameWheels: params.get('same_wheels') === '1',
  differentTypes: params.get('different_types') === '1'
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

// Scores the catalog's `models`, in the index's order, which the comparison's columns are in. Null for a format it
// doesn't know
export const scorer = (models, { format, fields }, activities) => {
  if (format !== FORMAT) return null

  const familyBySlug = new Map(activities.map(({ slug, family }) => [slug, family]))
  const families = models.map((model) => familyBySlug.get(model.primary_activity) ?? null)
  const columns = {
    ...fields,
    battery_size: fields.battery_size.map(log),
    groupset: fields.groupset_series.map(tier),
    suspension: models.map((model) => model.suspension ?? null),
    handlebar_type: models.map((model) => model.handlebar_type ?? null),
    primary_activity: models.map((model) => model.primary_activity ?? null),
    // its first, as one still sold isn't as new as it is current
    first_year: models.map(({ first_year: first }) => first ?? null),
    price: models.map((model) => log(model.msrp_cents)),
    // which a catalog published before bikebook added it lacks
    frame_material: fields.frame_material ?? models.map(() => null)
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

  // The `COUNT` models most like the one `id` names, of its propulsion, scored by `weights`, its maker's left out with
  // `skipManufacturer`, those of the other propulsion instead with `otherPropulsion`, which leaves its e-bike fields
  // unscored, only those complete as it is or isn't with `sameConfiguration`, only its wheel sizes, where it lists them,
  // with `sameWheels`, and other vehicle types only with
  // `differentTypes`, each the closest of its model group; and the sliders whose fields it has values for. Its own model
  // group's are always left out
  return (id, { weights, skipManufacturer, otherPropulsion, sameConfiguration, sameWheels, differentTypes }) => {
    const target = indexes.get(id)
    if (target == null) return null

    const model = models[target]
    const family = families[target]
    // each slider's weight shared among the fields the model lists, so a rigid bike, listing no travel, counts its suspension in full
    const listed = Object.entries(GROUPS).flatMap(([group, { fields }]) => {
      const own = Object.entries(fields).filter(([field]) => columns[field][target] != null)
      return own.map(([field, kind]) => ({
        group,
        field,
        kind,
        scale: kind === 'numeric' || kind === 'year' ? scaleOf(field, family) : null,
        weight: (weights[group] ?? 0) / own.length
      }))
    })
    const groups = [...new Set(listed.map(({ group }) => group))]
    const weighted = listed.filter(({ group, weight }) => weight > 0 && !(otherPropulsion && group === 'ebike'))
    const available = weighted.reduce((total, { weight }) => total + weight, 0)
    const required = weighted.filter(({ group, kind }) => weights[group] === MAX_WEIGHT && REQUIRABLE.includes(kind))
    if (!available) return { groups, models: [] }

    const scored = []
    models.forEach((candidate, index) => {
      if (index === target || candidate.model_group === model.model_group || (candidate.electric === model.electric) === otherPropulsion ||
        (!differentTypes && candidate.vehicle_type !== model.vehicle_type) ||
        (sameConfiguration && (candidate.model_configuration === 'complete') !== (model.model_configuration === 'complete')) ||
        (sameWheels && ['front_bsd', 'rear_bsd'].some((field) => columns[field][target] != null && columns[field][index] !== columns[field][target])) ||
        (skipManufacturer && candidate.manufacturer === model.manufacturer) ||
        required.some(({ field, kind, scale }) => columns[field][index] == null || KINDS[kind](columns[field][target], columns[field][index], scale) > 0)) return

      let shared = 0
      let total = 0
      for (const { field, kind, scale, weight } of weighted) {
        const value = columns[field][index]
        if (value == null || (field === 'price' && candidate.msrp_currency !== model.msrp_currency)) continue
        shared += weight
        total += weight * KINDS[kind](columns[field][target], value, scale)
      }
      const score = (total + (available - shared) * UNLISTED) / available
      if (shared >= MIN_SHARED * available && score < MAX_SCORE) scored.push({ model: candidate, score })
    })
    const grouped = new Set()
    const closest = scored.sort((a, b) => a.score - b.score).map(({ model }) => model)
      .filter(({ model_group: group }) => !grouped.has(group) && grouped.add(group))
    return { groups, models: closest.slice(0, COUNT) }
  }
}
