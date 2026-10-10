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
const blocks = new Map()
const orders = new Map()

const fetchJson = async (url) => {
  const response = await fetch(url)
  if (!response.ok) throw new Error(`${url} answered ${response.status}`)
  return response.json()
}

const list = (value) => (value ?? '').split(',').filter(Boolean)
// a classification's option and chip, beside the vehicles'
const classificationDisplay = ({ title }) => `e-Vehicle Classification: ${title}`
const path = (id) => id.replace(/^m\//, '')
const blockKey = (id) => path(id).split('/').slice(0, 2).join('/')

// The blocks `ids` are in load alongside the index rather than after it
async function load ({ manifestUrl, ids, jurisdictions }) {
  manifest = await fetchJson(manifestUrl)
  if (manifest.format !== FORMAT) throw new Error(`catalog format ${manifest.format} isn't ${FORMAT}`)

  base = new URL(manifestUrl, self.location)
  ids.map(blockKey).filter((key) => manifest.blocks[key]).forEach((key) => block(key).catch(() => {}))
  const [index, vocabulary, { kit }] = await Promise.all([manifest.index, manifest.vocabulary, manifest.kit].map((file) => fetchJson(new URL(file, base))))
  const currentYear = new Date().getFullYear()
  const activityNames = vocabulary.names.primary_activity ?? {}
  activities = index.primary_activities
  models = index.models.map((model) => ({
    ...model,
    // a photo stored under its model's id is published as its extension alone
    stock_photo: model.photo?.includes('/') ? model.photo : model.photo && `${index.stock_photos}/${path(model.id)}.${model.photo}`,
    activity_name: activityNames[model.primary_activity],
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
  return { vocabulary: { ...vocabulary, e_vehicle_classifications: classifications }, kit, options: options(index), modelsCount: models.length }
}

// Each filter's choices, with how many models choosing it alone matches. Propulsion's checkboxes show no counts
function options ({ manufacturers, vehicle_types: vehicleTypes, filter_options: { electric, e_vehicle_classification: classification, ...filterOptions } }) {
  const counted = (name, choices) => choices.map(([value, display]) => ({ value, display, count: models.filter(filter({ [name]: value })).length }))
  const perManufacturer = models.reduce((counts, { manufacturer }) => counts.set(manufacturer, (counts.get(manufacturer) ?? 0) + 1), new Map())
  return {
    primary_activity: counted('primary_activity', activities.map(({ slug, name }) => [slug, name])),
    manufacturer: Object.entries(manufacturers).filter(([slug]) => perManufacturer.has(slug)).sort(([, a], [, b]) => a.localeCompare(b))
      .map(([value, display]) => ({ value, display, count: perManufacturer.get(value) })),
    vehicle_type: counted('vehicle_type', vehicleTypes.map(({ slug, name }) => [slug, name])),
    ...Object.fromEntries(Object.entries(filterOptions).map(([name, labels]) => [name, counted(name, Object.entries(labels))]))
  }
}

// A failed fetch is forgotten, so the next ask tries again
const block = (key) => {
  if (!blocks.has(key)) {
    blocks.set(key, fetchJson(new URL(manifest.blocks[key], base)).then(({ models }) => models, (error) => {
      blocks.delete(key)
      throw error
    }))
  }
  return blocks.get(key)
}

// An e-vehicle classification's data is its vocabulary record
async function vehicles ({ ids }) {
  const found = await Promise.all(ids.map(async (value) => {
    if (classifications[value]) return { value, display: classificationDisplay(classifications[value]), data: classifications[value], classification: true }
    const key = blockKey(value)
    return { value, display: byId.get(value)?.display, data: manifest.blocks[key] && (await block(key))[value] }
  }))
  return found.filter(({ data }) => data)
}

function displays ({ ids }) {
  return ids.map((id) => byId.get(id)?.display ?? (classifications[id] ? classificationDisplay(classifications[id]) : null))
}

function search ({ params, page, perPage }) {
  const key = JSON.stringify(params)
  if (last?.key !== key) last = { key, ...matching(params) }

  const start = page * perPage
  return {
    total: last.matches.length,
    filteredCount: last.filteredCount,
    models: last.matches.slice(start, start + perPage),
    nextPage: last.matches.length > start + perPage ? page + 1 : null
  }
}

function matching (params) {
  const filtered = sorted(params).filter(filter(params))
  const needle = (params.q ?? '').trim().toLowerCase()
  const selected = new Set(list(params.vehicle_models))
  // a classification is found by its id alone, which every filter passes
  if (needle.startsWith('evc/')) {
    const matches = Object.entries(classifications).filter(([id]) => id.startsWith(needle) && !selected.has(id)).map(([id, record]) => ({ id, display: classificationDisplay(record), classification: true }))
    return { filteredCount: filtered.length, matches }
  }
  const exact = needle.startsWith('m/') && filtered.find(({ id }) => id === needle)
  const words = needle.split(/\s+/).filter(Boolean)
  const found = (exact ? [exact] : filtered.filter(({ searchText }) => words.every((word) => searchText.includes(word))))
    .filter(({ id }) => !selected.has(id))
  const whole = ({ searchText }) => searchText.includes(needle)
  const matches = needle ? [...found.filter(whole), ...found.filter((model) => !whole(model))] : found
  return { filteredCount: filtered.length, matches }
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
  const propulsions = list(params.electric)
  const types = list(params.vehicle_type)
  const [yearMin, yearMax, priceMin, priceMax] = ['year_min', 'year_max', 'price_min', 'price_max']
    .map((name) => params[name] ? parseInt(params[name], 10) || 0 : null)

  return (model) =>
    (allowed.size === 0 || allowed.has(model.primary_activity)) &&
    (manufacturers.length === 0 || manufacturers.includes(model.manufacturer)) &&
    (propulsions.length === 0 || propulsions.some((propulsion) => propelled(model, propulsion))) &&
    (!params.suspension || (params.suspension === 'has' ? model.suspension !== 'rigid' : model.suspension === params.suspension)) &&
    (types.length === 0 || types.includes(model.vehicle_type)) &&
    (!params.model_configuration || model.model_configuration === params.model_configuration) &&
    (yearMin == null || model.sortYear >= yearMin) &&
    (yearMax == null || (model.first_year ?? 0) <= yearMax) &&
    ((priceMin == null && priceMax == null) || (model.msrp_cents > 0 &&
      (priceMin == null || model.msrp_cents >= priceMin * 100) && (priceMax == null || model.msrp_cents <= priceMax * 100)))
}

// out_of_class is the catalog's own marker, as a model with no classified mode is unknown rather than out of class.
// A state's class matches the models carrying its groups
function propelled ({ electric, e_vehicle_classifications: carried = [] }, propulsion) {
  if (propulsion === '0' || propulsion === '1') return electric === (propulsion === '1')
  const id = propulsion.replace(/^class_/, 'evc/us/class_')
  return [id, ...(classifications[id]?.groups ?? [])].some((classification) => carried.includes(classification))
}

self.onmessage = async ({ data: { id, type, ...args } }) => {
  try {
    self.postMessage({ id, result: await { load, search, vehicles, displays }[type](args) })
  } catch (error) {
    self.postMessage({ id, error: error.message })
  }
}
