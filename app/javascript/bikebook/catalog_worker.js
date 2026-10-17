// Searches the published catalog off the main thread, by the rules the catalog's own search follows
/* global self */

const FORMAT = 2

let models = []
let byId = new Map()
let classifications = {}
let activities = []
let manifest = null
let base = null
let last = null
let rules = null
const blocks = new Map()
const orders = new Map()

const fetchJson = async (url) => {
  const response = await fetch(url)
  if (!response.ok) throw new Error(`${url} answered ${response.status}`)
  return response.json()
}

const list = (value) => (value ?? '').split(',').filter(Boolean)
const path = (id) => id.replace(/^m\//, '')
const blockKey = (id) => path(id).split('/').slice(0, 2).join('/')

// The blocks `ids` are in load alongside the index rather than after it
async function load ({ manifestUrl, ids, jurisdictions, rulesUrl }) {
  ;[manifest, rules] = await Promise.all([fetchJson(manifestUrl), import(rulesUrl)])
  if (manifest.format !== FORMAT) throw new Error(`catalog format ${manifest.format} isn't ${FORMAT}`)

  base = new URL(manifestUrl, self.location)
  ids.map(blockKey).filter((key) => manifest.blocks[key]).forEach((key) => block(key).catch(() => {}))
  const [index, vocabulary, { kit }] = await Promise.all([manifest.index, manifest.vocabulary, manifest.kit].map((file) => fetchJson(new URL(file, base))))
  const currentYear = new Date().getFullYear()
  const activityNames = vocabulary.names.primary_activity ?? {}
  const typeNames = Object.fromEntries(index.vehicle_types.map(({ slug, name }) => [slug, name]))
  activities = index.primary_activities
  models = index.models.map((model) => ({
    ...model,
    // a photo stored under its model's id is published as its extension alone
    stock_photo: model.photo?.includes('/') ? model.photo : model.photo && `${index.stock_photos}/${path(model.id)}.${model.photo}`,
    activity_name: activityNames[model.primary_activity],
    type_name: typeNames[model.vehicle_type],
    searchText: `${model.display}\n${model.id}`.toLowerCase(),
    sortYear: model.final_year ?? currentYear,
    sortPrice: model.msrp_cents ?? 0
  }))
  byId = new Map(models.map((model) => [model.id, model]))
  // "California Moped", which its name leaves off the state of, and a group has none; "US Class 3 e-bike"
  classifications = Object.fromEntries(Object.entries(vocabulary.e_vehicle_classifications).map(([id, record]) => {
    const code = record.jurisdiction
    const state = code?.startsWith('US-') && (jurisdictions[code] ?? code)
    const label = [state || code, record.name].filter(Boolean).join(' ')
    // "Alabama (AL)", "United States"
    const jurisdictionName = state ? `${state} (${code.slice(3)})` : code && (jurisdictions[code] ?? code)
    return [id, { ...record, label, jurisdiction_name: jurisdictionName, title: /^Class \d+$/.test(record.name) ? `${label} e-bike` : label }]
  }))
  return { vocabulary: { ...vocabulary, e_vehicle_classifications: classifications }, kit, options: options(index) }
}

// Each filter's choices, with how many models choosing it alone matches. Propulsion's checkboxes show no counts
function options ({ manufacturers, vehicle_types: vehicleTypes, filter_options: { electric, e_vehicle_classification: classification, market, ...filterOptions } }) {
  const counted = (name, choices) => choices.map(([value, display]) => ({ value, display, count: models.filter(filter({ [name]: value })).length }))
  const perManufacturer = models.reduce((counts, { manufacturer }) => counts.set(manufacturer, (counts.get(manufacturer) ?? 0) + 1), new Map())
  return {
    primary_activity: counted('primary_activity', activities.map(({ slug, name }) => [slug, name])),
    manufacturer: Object.entries(manufacturers).filter(([slug]) => perManufacturer.has(slug)).sort(([, a], [, b]) => a.localeCompare(b))
      .map(([value, display]) => ({ value, display, count: perManufacturer.get(value) })),
    vehicle_type: counted('vehicle_type', vehicleTypes.map(({ slug, name }) => [slug, name])),
    // "Canada (CA)", as UI::Forms::ComboboxState shows a state
    market: counted('market', Object.entries(market).sort(([, a], [, b]) => a.localeCompare(b)))
      .map((option) => ({ ...option, name: option.display, display: `${option.display} (${option.value})` })),
    ...Object.fromEntries(Object.entries(filterOptions).map(([name, labels]) => [name, counted(name, Object.entries(labels))]))
  }
}

const withYearRecords = (vehicle) => vehicle.years
  ? { ...vehicle, years: Object.entries(vehicle.years).map(([year, record]) => ({ year: Number(year), ...record })).sort((a, b) => b.year - a.year) }
  : vehicle

// A failed fetch is forgotten, so the next ask tries again
const block = (key) => {
  if (!blocks.has(key)) {
    blocks.set(key, fetchJson(new URL(manifest.blocks[key], base)).then(({ models }) => Object.fromEntries(Object.entries(models).map(([id, data]) => [id, withYearRecords(data)])), (error) => {
      blocks.delete(key)
      throw error
    }))
  }
  return blocks.get(key)
}

// A block leaves out the markets of a model sold in its maker's primary market alone, which the index resolves.
// `outsideMarket` where it isn't sold in `market`, blank for any
async function vehicles ({ ids, market }) {
  const found = await Promise.all(ids.map(async (value) => {
    const key = blockKey(value)
    const data = manifest.blocks[key] && (await block(key))[value]
    const model = byId.get(value)
    return {
      value,
      display: model?.display,
      data: data && { ...data, markets: data.markets ?? model?.markets },
      outsideMarket: Boolean(market) && !model?.markets.includes(market)
    }
  }))
  return found.filter(({ data }) => data)
}

function displays ({ ids }) {
  return ids.map((id) => byId.get(id)?.display ?? null)
}

function search ({ params, page, perPage }) {
  const key = JSON.stringify(params)
  if (last?.key !== key) last = { key, ...matching(params) }

  const start = page * perPage
  return {
    total: last.matches.length,
    filteredCount: last.filteredCount,
    unfiltered: last.unfiltered,
    models: last.matches.slice(start, start + perPage),
    nextPage: last.matches.length > start + perPage ? page + 1 : null
  }
}

// A model's exact id finds it though the filters leave it out, which `unfiltered` says
function matching (params) {
  const passes = filter(params)
  const filtered = sorted(params).filter(passes)
  const needle = (params.q ?? '').trim().toLowerCase()
  const selected = new Set(list(params.vehicle_models))
  const exact = needle.startsWith('m/') && byId.get(needle)
  const words = needle.split(/\s+/).filter(Boolean)
  const found = (exact ? [exact] : filtered.filter(({ searchText }) => words.every((word) => searchText.includes(word))))
    .filter(({ id }) => !selected.has(id))
  const whole = ({ searchText }) => searchText.includes(needle)
  const matches = needle ? [...found.filter(whole), ...found.filter((model) => !whole(model))] : found
  return { filteredCount: filtered.length, matches, unfiltered: Boolean(exact) && matches.length > 0 && !passes(exact) }
}

// The `count` of models the filters leave, and featured_rules' `COUNT` of them, by its rules, in the filters' order.
// `legalClasses` are the e-bike classes legal where the visitor is, by which every e-bike is legal where there are none
function featured ({ params, legalClasses }) {
  const { COUNT, requirements, preferences, quotas } = rules
  const legalEbike = (model) => !legalClasses.length || legalClasses.some((propulsion) => propelled(model, propulsion, params.jurisdiction))
  const filtered = sorted(params).filter(filter(params))
  const candidates = requirements.reduce((models, requirement) => {
    const passing = models.filter((model) => requirement(model, { legalEbike }))
    return passing.length ? passing : models
  }, filtered)
  const count = Math.min(COUNT, candidates.length)
  // a share's models and the others each at least their part of the picks
  const minimums = quotas.flatMap(({ matches, share, minimum = Math.round(count * share) }) => share == null
    ? [{ matches, minimum }]
    : [{ matches, minimum }, { matches: (model) => !matches(model), minimum: count - minimum }])
  const picked = []
  while (picked.length < count) {
    const pool = minimums.reduce((models, { matches, minimum }) => {
      const narrowed = minimum - picked.filter(matches).length >= count - picked.length && models.filter(matches)
      return narrowed?.length ? narrowed : models
    }, candidates.filter((model) => !picked.includes(model)))
    // a share's models while the picks fall short of it and the others while they're over, a minimum's until it's met.
    // A quota met ranks every model alike
    const behind = quotas.map(({ matches, share, minimum }) => (share == null ? minimum : share * picked.length) - picked.filter(matches).length)
    const helps = (model) => quotas.map(({ matches, share }, index) => share == null
      ? behind[index] <= 0 || matches(model)
      : behind[index] === 0 || (behind[index] > 0) === matches(model))
    const ranks = (model) => [...preferences.map((prefers) => prefers(model, { picked })), ...helps(model)]
    // no model outranks one meeting every rank
    let best = null
    for (const model of pool) {
      const modelRanks = ranks(model)
      if (!best || outranks(modelRanks, best.ranks)) best = { model, ranks: modelRanks }
      if (modelRanks.every(Boolean)) break
    }
    picked.push(best.model)
  }
  return { count: filtered.length, featured: candidates.filter((model) => picked.includes(model)) }
}

// Whether `a` wins at the first rank the two differ at
const outranks = (a, b) => {
  const index = a.findIndex((value, each) => value !== b[each])
  return index !== -1 && a[index]
}

// Newest and priciest first unless asked otherwise, kept per pair of directions so a query only has to filter
function sorted ({ year_dir: yearDir, price_dir: priceDir }) {
  const key = `${yearDir}/${priceDir}`
  if (!orders.has(key)) {
    const direction = (dir) => dir === 'asc' ? 1 : -1
    orders.set(key, [...models].sort((a, b) =>
      direction(yearDir) * (a.sortYear - b.sortYear) || direction(priceDir) * (a.sortPrice - b.sortPrice) || (a.id < b.id ? -1 : 1)))
  }
  return orders.get(key)
}

// A family matches its flavors; slugs naming no activity filter nothing
function filter (params) {
  const chosen = list(params.primary_activity)
  const allowed = new Set(activities.filter(({ slug, family }) => chosen.includes(slug) || chosen.includes(family)).map(({ slug }) => slug))
  const manufacturers = list(params.manufacturer)
  // checked classes are the e-vehicles wanted, which the e-Vehicle (motorized) they check would widen to all of them
  const electric = list(params.electric)
  const classes = electric.filter((value) => value !== '0' && value !== '1')
  const propulsions = classes.length ? classes : electric
  const types = list(params.vehicle_type)
  const [yearMin, yearMax, priceMin, priceMax] = ['year_min', 'year_max', 'price_min', 'price_max']
    .map((name) => params[name] ? parseInt(params[name], 10) || 0 : null)

  return (model) =>
    (allowed.size === 0 || allowed.has(model.primary_activity)) &&
    (manufacturers.length === 0 || manufacturers.includes(model.manufacturer)) &&
    (propulsions.length === 0 || propulsions.some((propulsion) => propelled(model, propulsion, params.jurisdiction))) &&
    (!params.suspension || (params.suspension === 'has' ? model.suspension !== 'rigid' : model.suspension === params.suspension)) &&
    (types.length === 0 || types.includes(model.vehicle_type)) &&
    (!params.model_configuration || model.model_configuration === params.model_configuration) &&
    (!params.market || model.markets.includes(params.market)) &&
    (yearMin == null || model.sortYear >= yearMin) &&
    (yearMax == null || (model.first_year ?? 0) <= yearMax) &&
    ((priceMin == null && priceMax == null) || (model.msrp_cents > 0 &&
      (priceMin == null || model.msrp_cents >= priceMin * 100) && (priceMax == null || model.msrp_cents <= priceMax * 100)))
}

// out_of_class is the catalog's own marker, as a model with no classified mode is unknown rather than out of class, and
// out_of_class/US-CA its marker for one in no class in that state alone, where it's out of class rather than the US
// classes it carries. A state's class matches the models carrying its groups
function propelled ({ electric, e_vehicle_classifications: carried = [] }, propulsion, jurisdiction) {
  if (propulsion === '0' || propulsion === '1') return electric === (propulsion === '1')
  const id = propulsion.replace(/^class_/, 'evc/us/class_')
  if (/^(out_of_class|evc\/us\/class_\d)$/.test(id) && carried.includes(`out_of_class/US-${jurisdiction}`)) return id === 'out_of_class'
  return [id, ...(classifications[id]?.groups ?? [])].some((classification) => carried.includes(classification))
}

self.onmessage = async ({ data: { id, type, ...args } }) => {
  try {
    self.postMessage({ id, result: await { load, search, featured, vehicles, displays }[type](args) })
  } catch (error) {
    self.postMessage({ id, error: error.message })
  }
}
