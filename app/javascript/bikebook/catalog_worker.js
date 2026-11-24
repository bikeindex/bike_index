// Searches the published catalog off the main thread, by the rules the catalog's own search follows
/* global self */

const FORMAT = 5

let models = []
let byId = new Map()
let bases = new Map()
let classifications = {}
let activities = []
let manifest = null
let base = null
let last = null
let rules = null
let similarityUrl = null
let similarity = null
let comparison = null
let lastSimilar = null
let opened = null
let started = null
let comparisonFetch = null
const blocks = new Map()
const orders = new Map()
const sold = new Map()

// A stalled download never fails on its own. The wait restarts with each part, as the index takes most of a minute on 3G
const STALL_TIMEOUT = 30000

const fetchJson = async (url) => {
  const stalled = new AbortController()
  let timeout
  const waiting = () => {
    clearTimeout(timeout)
    timeout = setTimeout(() => stalled.abort(), STALL_TIMEOUT)
  }
  waiting()
  try {
    const response = await fetch(url, { signal: stalled.signal })
    if (!response.ok) throw new Error(`${url} answered ${response.status}`)
    return await new Response(response.body.pipeThrough(new TransformStream({
      transform: (chunk, stream) => {
        waiting()
        stream.enqueue(chunk)
      }
    }))).json()
  } finally {
    clearTimeout(timeout)
  }
}

// Schema 2.0.0's ids are dashed. An older catalog's are underscored and never dashed, so they read as 2.0.0's, as
// Integrations::Bikebook::Catalog.dashed_ids reads them
// TODO: once the published catalog is at 2.0.0, remove this
const CATALOG_ID = /^(?:(?:m|c|evc)\/[a-z0-9_/-]+(?:@[A-Z]+)?|[a-z0-9_-]+\/\d{4})$/
const dashed = (value) => typeof value === 'string' ? value.replaceAll('_', '-') : value
const dashedIds = (value) => {
  if (Array.isArray(value)) return value.map(dashedIds)
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([key, each]) => [dashedIds(key), dashedIds(each)]))
  return typeof value === 'string' && CATALOG_ID.test(value) ? dashed(value) : value
}
const fetchCatalog = (url) => fetchJson(url).then(dashedIds)

// Schema 2.0.0's slugs for the vocabulary Bike Index reads values of, which an older catalog underscores, and where 2.0.0
// renamed one, names otherwise. Integrations::Bikebook::Catalog.current_slug reads them the same way
// TODO: once the published catalog is at 2.0.0, remove this
const RENAMED = {
  __proto__: null,
  bike_trailer: 'trailer',
  cargo_bike: 'cargo',
  cargo_bike_rear: 'cargo-rear',
  cargo_tricycle: 'cargo-trike',
  cargo_tricycle_rear: 'cargo-trike-rear',
  epamd: 'personal-mobility',
  scooter: 'non-e-scooter',
  skateboard: 'non-e-skateboard',
  elliptical_bike: 'elliptical',
  road_endurance: 'road-endurance-sportive',
  carbon: 'composite',
  wood: 'organic'
}
const currentSlug = (value) => Array.isArray(value) ? value.map(currentSlug) : RENAMED[value] ?? dashed(value)
// each a record's field, or a field of what it holds, and the vocabulary naming it
const SLUGGED = ['type', 'type_detail', 'primary_activity', 'drivetrain', 'frame.material', 'components.type']
const withSlug = (record, [key, field]) => {
  const value = record[key]
  if (value == null) return record
  if (!field) return { ...record, [key]: currentSlug(value) }
  return { ...record, [key]: Array.isArray(value) ? value.map((each) => withSlug(each, [field])) : withSlug(value, [field]) }
}
const withCurrentSlugs = (record) => SLUGGED.reduce((each, path) => withSlug(each, path.split('.')), record)
const rekeyed = (names) => Object.fromEntries(Object.entries(names).map(([value, name]) => [currentSlug(value), name]))
const withCurrentNames = (names) => ({ ...names, ...Object.fromEntries(SLUGGED.filter((path) => names[path]).map((path) => [path, rekeyed(names[path])])) })

const list = (value) => (value ?? '').split(',').filter(Boolean)
const path = (id) => id.replace(/^m\//, '')
const blockKey = (id) => path(id).split('/').slice(0, 2).join('/')

// "California Moped", which its name leaves off the state of, and a group has none; "US Class 3 e-bike"
const classified = ({ e_vehicle_classifications: records }, jurisdictions) => Object.fromEntries(Object.entries(records).map(([id, record]) => {
  const code = record.jurisdiction
  const state = code?.startsWith('US-') && (jurisdictions[code] ?? code)
  const label = [state || code, record.name].filter(Boolean).join(' ')
  // "Alabama (AL)", "United States"
  const jurisdictionName = state ? `${state} (${code.slice(3)})` : code && (jurisdictions[code] ?? code)
  return [id, { ...record, label, jurisdiction_name: jurisdictionName, title: /^Class \d+$/.test(record.name) ? `${label} e-bike` : label }]
}))

// What picked vehicles render from, which needs nothing of the index: the blocks `ids` are in, the kit and the vocabulary
function start ({ manifestUrl, ids, jurisdictions, riders, comparing }) {
  opened = fetchCatalog(manifestUrl).then((published) => {
    if (published.format !== FORMAT) throw new Error(`catalog format ${published.format} isn't ${FORMAT}`)

    manifest = published
    base = new URL(manifestUrl, self.location)
    ids.map(blockKey).filter((key) => manifest.blocks[key]).forEach((key) => block(key).catch(() => {}))
  })
  started = opened.then(() => Promise.all([manifest.vocabulary, manifest.kit].map((file) => fetchCatalog(new URL(file, base)))))
    .then(([vocabulary, { kit }]) => ({ vocabulary: { ...vocabulary, names: withCurrentNames({ target_riders: riders, ...vocabulary.names }), e_vehicle_classifications: classified(vocabulary, jurisdictions) }, kit }))
  if (comparing) fetchComparison()
  return started
}

// After `start`, whose manifest and files it waits on
async function load ({ rulesUrl, similarityUrl: similarityModule }) {
  similarityUrl = similarityModule
  const [published, { vocabulary, kit }, featuredRules] = await Promise.all([opened.then(() => fetchJson(new URL(manifest.index, base))), started, import(rulesUrl)])
  const index = {
    ...published,
    manufacturers: Object.fromEntries(Object.entries(published.manufacturers).map(([slug, name]) => [dashed(slug), name])),
    primary_activities: published.primary_activities.map((each) => ({ ...each, slug: currentSlug(each.slug), family: currentSlug(each.family) })),
    vehicle_types: published.vehicle_types.map((each) => ({ ...each, slug: currentSlug(each.slug) })),
    filter_options: dashedIds(published.filter_options)
  }
  rules = featuredRules
  const currentYear = new Date().getFullYear()
  const activityNames = vocabulary.names.primary_activity ?? {}
  const typeNames = Object.fromEntries(index.vehicle_types.map(({ slug, name }) => [slug, name]))
  activities = index.primary_activities
  models = index.models.map((model, position) => {
    // field by field, as walking the whole index takes three times its parse
    const id = dashedIds(model.id)
    const manufacturer = dashed(model.manufacturer)
    const activity = currentSlug(model.primary_activity)
    const type = currentSlug(model.vehicle_type)
    return {
      ...model,
      id,
      manufacturer,
      primary_activity: activity,
      vehicle_type: type,
      e_vehicle_classifications: dashedIds(model.e_vehicle_classifications),
      variants: dashedIds(model.variants),
      position,
      // an extension at its own path, or the whole URL of a photo it shares with another model, by its published id
      stock_photo: model.photo && (model.photo.includes('://') ? model.photo : `${index.stock_photos}/${path(model.id)}.${model.photo}`),
      activity_name: activityNames[activity],
      type_name: typeNames[type],
      // by its maker, as makers share names, and its first word where it has no group
      group_key: `${manufacturer}/${model.model_group ?? model.model.split(' ')[0]}`,
      searchText: `${model.display}\n${id}`.toLowerCase(),
      // a current model's first year where it's sold ahead of the calendar
      sortYear: model.final_year ?? Math.max(model.first_year, currentYear),
      // drawn per worker, which each page load starts, and again by `rotate`, so a reload features others and the page's
      // own changes the same
      chance: Math.random()
    }
  })
  // a market variant is its base's row under its own id and markets
  const variants = models.flatMap((model) => model.variants.map(({ id, markets }) => [{ ...model, id, markets, variants: [] }, model]))
  bases = new Map(variants.map(([variant, model]) => [variant.id, model]))
  byId = new Map([...models, ...variants.map(([variant]) => variant)].map((model) => [model.id, model]))
  // the index labels the out of class markers, which the vocabulary has no record of: "Out of class in California"
  const labels = Object.entries(index.filter_options.e_vehicle_classification).map(([id, label]) => [id, { label, title: label, marker: true }])
  classifications = { ...Object.fromEntries(labels), ...vocabulary.e_vehicle_classifications }
  return { vocabulary: { ...vocabulary, e_vehicle_classifications: classifications }, kit, options: options(index, vocabulary.names) }
}

const fetchComparison = () => (comparisonFetch ??= opened.then(() => manifest.comparison && fetchJson(new URL(manifest.comparison, base)))
  .then((published) => published && { ...published, fields: { ...published.fields, frame_material: currentSlug(published.fields.frame_material) } }).catch(() => null))

// The comparison, once the index, whose order it's in, has loaded, for its frame materials as well as how alike models are;
// without it neither is offered. Fetched when it's asked for, leaving the index the connection, unless `start` is told the
// page is of what it adds
async function compare () {
  comparison = await fetchComparison()
  if (!comparison) return { comparable: false, frameMaterials: [] }

  last = null
  return { comparable: true, frameMaterials: named('frame_material', 'frame.material', (await started).vocabulary.names) }
}

// a model's riders as a single choice: "kid,woman" is the kids' women's models alone
const ridersOf = ({ target_riders: riders }) => (riders ?? []).join(',')

const counted = (name, choices) => choices.map(([value, display]) => ({ value, display, count: models.filter(filter({ [name]: value })).length }))

// by the vocabulary, as the index offers no choices of these
const named = (name, vocabulary, names) => counted(name, Object.entries(names[vocabulary] ?? {})).filter(({ count }) => count)

// Each filter's choices, with how many models choosing it alone matches. Propulsion's checkboxes show no counts
function options ({ manufacturers, vehicle_types: vehicleTypes, filter_options: { electric, e_vehicle_classification: classification, market, ...filterOptions } }, names) {
  const sellers = new Set(models.flatMap(marketsOf))
  const perManufacturer = models.reduce((counts, { manufacturer }) => counts.set(manufacturer, (counts.get(manufacturer) ?? 0) + 1), new Map())
  return {
    primary_activity: counted('primary_activity', activities.map(({ slug, name }) => [slug, name])),
    manufacturer: Object.entries(manufacturers).filter(([slug]) => perManufacturer.has(slug)).sort(([, a], [, b]) => a.localeCompare(b))
      .map(([value, display]) => ({ value, display, count: perManufacturer.get(value) })),
    vehicle_type: counted('vehicle_type', vehicleTypes.map(({ slug, name }) => [slug, name])),
    // "Canada (CA)", as UI::Forms::ComboboxState shows a state; only those with models sold there, as most have none
    market: Object.entries(market).sort(([, a], [, b]) => a.localeCompare(b)).filter(([value]) => sellers.has(value))
      .map(([value, display]) => ({ value, name: display, display: `${display} (${value})` })),
    ...Object.fromEntries(Object.entries(filterOptions).map(([name, labels]) => [name, counted(name, Object.entries(labels))])),
    handlebar_type: named('handlebar_type', 'handlebar_type', names),
    target_riders: counted('target_riders', [...new Set(models.map(ridersOf).filter(Boolean))]
      .map((value) => [value, value.split(',').map((rider) => names.target_riders[rider] ?? rider).join(' & ')]))
      .sort((a, b) => b.count - a.count),
    frame_material: []
  }
}

const withYearRecords = (vehicle) => vehicle.years
  ? { ...vehicle, years: Object.entries(vehicle.years).map(([year, record]) => ({ year: Number(year), ...record })).sort((a, b) => b.year - a.year) }
  : vehicle

// An array of these merges item by item, keyed by each item's values for them (an empty list by position); any other
// array is replaced whole
const IDENTITIES = {
  colorways: ['name'],
  components: ['type', 'position', 'type_detail'],
  motors: [],
  operating_modes: ['mode', 'availability', 'markets'],
  sizes: ['name'],
  mounts: ['type'],
  wheels: ['position', 'bsd'],
  brakes: ['position']
}
const isObject = (value) => value != null && typeof value === 'object' && !Array.isArray(value)
const keyed = (key, items) => Object.fromEntries(items.map((item, index) => [
  IDENTITIES[key].length ? IDENTITIES[key].map((field) => [item[field] ?? []].flat().join('+')).filter(Boolean).join(' ') : String(index),
  item
]))

// false removes an object the home market's has (a year's record, a wheel), null any other value
const merged = (record, changes) => Object.entries(changes).reduce((out, [key, value]) => {
  if (value === null || (value === false && isObject(out[key]))) return except(out, key)
  if (isObject(value) && Array.isArray(out[key])) return { ...out, [key]: Object.values(merged(keyed(key, out[key]), value)) }
  return { ...out, [key]: isObject(value) && isObject(out[key]) ? merged(out[key], value) : value }
}, record)
const except = (record, key) => Object.fromEntries(Object.entries(record).filter(([each]) => each !== key))

// From schema 1.1.0, a market's model sits in its home market's record, under `market_variants` keyed by the market its
// citation key names, as what differs from it; before, it's a record of its own. Its id is its home market's, as in a
// format 5 block. Integrations::Bikebook::MarketVariants expands them the same way
const withMarketVariants = (models) => Object.fromEntries(Object.entries(models).flatMap(([id, record]) => {
  const home = except(record, 'market_variants')
  return [[id, home], ...Object.entries(record.market_variants ?? {}).map(([market, changes]) => [`${id}@${market}`, merged(home, changes)])]
}))

// A failed fetch is forgotten, so the next ask tries again
const block = (key) => {
  if (!blocks.has(key)) {
    blocks.set(key, fetchCatalog(new URL(manifest.blocks[key], base)).then(({ models }) => Object.fromEntries(Object.entries(withMarketVariants(models)).map(([id, data]) => [id, withYearRecords(withCurrentSlugs(data))])), (error) => {
      blocks.delete(key)
      throw error
    }))
  }
  return blocks.get(key)
}

const blockData = async (id) => manifest.blocks[blockKey(id)] && (await block(blockKey(id)))[id]

// A block leaves out the markets of a model sold in its maker's primary market alone, which the index resolves. Its final
// year says whether it's current, which a market variant's row, its base's, doesn't. `outsideMarket` where it isn't sold
// in `market`, blank for any
async function vehicles ({ ids, market }) {
  const found = await Promise.all(ids.map(async (value) => {
    const data = await blockData(value)
    const model = byId.get(value)
    return {
      value,
      display: model?.display,
      data: data && { ...data, markets: data.markets ?? model?.markets },
      outsideMarket: Boolean(market) && !model?.markets.includes(market),
      current: Boolean(model) && data?.final_year == null
    }
  }))
  return found.filter(({ data }) => data)
}

// Imported once something asks how alike models are. Null without a comparison, or one in a format the scorer doesn't know
const scorer = () => {
  similarity ??= import(similarityUrl).then(({ scorer }) => comparison && scorer(models, comparison, activities), (error) => {
    similarity = null
    throw error
  })
  return similarity
}

// the last scoring kept, as the page asks again on each render while the section is open. Of the models the search's
// `filters` leave, of the model's own propulsion and vehicle type where they pick none
async function similar ({ model, settings, filters: { sort, year_dir: yearDir, price_dir: priceDir, ...filters } }) {
  const score = await scorer()
  const key = JSON.stringify({ model, settings, filters })
  if (lastSimilar?.key !== key) {
    const own = baseOf(model)
    const matches = filter({ ...filters, electric: filters.electric || (own?.electric ? '1' : '0'), vehicle_type: filters.vehicle_type || own?.vehicle_type })
    // current as `vehicles` says
    const includeNotCurrent = settings.includeNotCurrent ?? (await blockData(model))?.final_year != null
    const result = own && score?.(own.id, { ...settings, includeNotCurrent }, matches)
    lastSimilar = { key, result: result ? { ...result, models: result.models.map((each) => soldIn(each, filters.market)) } : null }
  }
  return lastSimilar.result
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
  // a citation key's market is upper case: m/specialized/2025/haul-st@CA
  const exact = needle.startsWith('m/') && byId.get(dashedIds(needle.replace(/@[a-z]+$/, (market) => market.toUpperCase())))
  const words = needle.split(/\s+/).filter(Boolean)
  const found = exact ? [exact] : filtered.filter(({ searchText }) => words.every((word) => searchText.includes(word))).map((model) => soldIn(model, params.market))
  const whole = ({ searchText }) => searchText.includes(needle)
  const matches = needle ? [...found.filter(whole), ...found.filter((model) => !whole(model))] : found
  // by its own markets rather than its variants'
  return { filteredCount: filtered.length, matches, unfiltered: Boolean(exact) && matches.length > 0 && !passes({ ...exact, variants: [] }) }
}

// The `count` of models the filters leave, and featured_rules' `COUNT` of them, by its rules, the models tying on them
// by `chance`, shown cheapest first unless the reader picked a sort, and whether a rotation could pick others.
// `legalClasses` are the e-bike classes legal where the visitor is, by which every e-bike is legal where there are none
function featured ({ params, legalClasses }) {
  const { COUNT, requirements, preferences, quotas, maximums } = rules
  const legalEbike = (model) => !legalClasses.length || legalClasses.some((propulsion) => propelled(model, propulsion, params.jurisdiction))
  const filtered = models.filter(filter(params))
  const candidates = requirements.reduce((models, requirement) => narrow(models, (model) => requirement(model, { legalEbike, params })), filtered)
    .toSorted((a, b) => a.chance - b.chance)
  const count = Math.min(COUNT, candidates.length)
  // a share's models and the others each at least their part of the picks
  const minimums = quotas.flatMap(({ matches, share, minimum = Math.round(count * share) }) => share == null
    ? [{ matches, minimum }]
    : [{ matches, minimum }, { matches: (model) => !matches(model), minimum: count - minimum }])
  // each candidate's quota matches, and the different ones among them, which bound the ranks any can reach
  const matched = new Map(candidates.map((model) => [model, quotas.map(({ matches }) => matches(model))]))
  const kinds = [...new Map([...matched.values()].map((each) => [each.join(), each])).values()]
  const picked = []
  while (picked.length < count) {
    const capped = maximums.reduce((models, { matches, maximum }) => picked.filter(matches).length < maximum
      ? models
      : narrow(models, (model) => !matches(model)), candidates.filter((model) => !picked.includes(model)))
    const pool = minimums.reduce((models, { matches, minimum }) => minimum - picked.filter(matches).length >= count - picked.length
      ? narrow(models, matches)
      : models, capped)
    // a share's models while the picks fall short of it and the others while they're over, a minimum's until it's met.
    // A quota met ranks every model alike
    const behind = quotas.map(({ matches, share, minimum }) => (share == null ? minimum : share * picked.length) - picked.filter(matches).length)
    const helps = (matching) => quotas.map(({ share }, index) => share == null
      ? behind[index] <= 0 || matching[index]
      : behind[index] === 0 || (behind[index] > 0) === matching[index])
    const ranks = (model) => [...preferences.map((prefers) => prefers(model, { picked })), ...helps(matched.get(model))]
    // no model outranks one reaching the ranks a model with every preference would
    const ceiling = kinds.map((each) => [...preferences.map(() => true), ...helps(each)]).reduce((top, each) => outranks(each, top) ? each : top)
    let best = null
    for (const model of pool) {
      const modelRanks = ranks(model)
      if (!best || outranks(modelRanks, best.ranks)) best = { model, ranks: modelRanks }
      if (!outranks(ceiling, modelRanks)) break
    }
    picked.push(best.model)
  }
  const shown = params.sort || params.year_dir || params.price_dir ? params : { sort: 'price' }
  const featured = sorted(shown).filter((model) => picked.includes(model)).map((model) => soldIn(model, params.market))
  return { count: filtered.length, featured, rotatable: candidates.length > COUNT }
}

// featured's picks drawn afresh, as a reload would
function rotate () {
  for (const model of models) model.chance = Math.random()
}

// The models of the `model` id's group by year, newest first, each under the newest it's sold in - so each once, and a
// current one in this year. Those `market` leaves out by its `scope`, as a search would, but the model itself
function group ({ model: id, market, scope }) {
  const model = baseOf(id)
  if (!model?.model_group) return null

  const years = new Map()
  for (const each of sorted({}).filter((each) => each.manufacturer === model.manufacturer && each.model_group === model.model_group && each.first_year &&
    (each === model || !market || inMarket(each, market, scope)))) {
    years.set(each.sortYear, [...(years.get(each.sortYear) ?? []), soldIn(each, market)])
  }
  return {
    name: model.model_group,
    manufacturer: model.manufacturer_name,
    years: [...years].sort(([a], [b]) => b - a).map(([year, models]) => ({ year, models }))
  }
}

// `models` that `keep` keeps, unless that's none
const narrow = (models, keep) => (kept => kept.length ? kept : models)(models.filter(keep))

// Whether `a` wins at the first rank the two differ at
const outranks = (a, b) => {
  const index = a.findIndex((value, each) => value !== b[each])
  return index !== -1 && a[index]
}

// Newest and cheapest first unless asked otherwise, by year then price unless `sort` puts price first, the unpriced last
// either way. Kept per order, so a query only has to filter
function sorted ({ sort, year_dir: yearDir, price_dir: priceDir }) {
  const key = `${sort}/${yearDir}/${priceDir}`
  if (!orders.has(key)) {
    const byYear = (a, b) => (yearDir === 'asc' ? 1 : -1) * (a.sortYear - b.sortYear)
    const byPrice = (a, b) => (a.msrp_cents == null) - (b.msrp_cents == null) || (priceDir === 'desc' ? -1 : 1) * (a.msrp_cents - b.msrp_cents)
    const [first, second] = sort === 'price' ? [byPrice, byYear] : [byYear, byPrice]
    orders.set(key, [...models].sort((a, b) => first(a, b) || second(a, b) || (a.id < b.id ? -1 : 1)))
  }
  return orders.get(key)
}

// the manufacturers with models sold in `market`
const sellingIn = (market) => {
  if (!sold.has(market)) sold.set(market, new Set(models.filter((model) => marketsOf(model).includes(market)).map(({ manufacturer }) => manufacturer)))
  return sold.get(market)
}

// Its own models alone `only`, or every one for `any`. Preferring it, the default, adds the models sold elsewhere but
// for e-vehicles, which its own laws class, and the makers it sells any of
const inMarket = (model, market, scope) => scope === 'any' || marketsOf(model).includes(market) ||
  (scope !== 'only' && !model.electric && !sellingIn(market).has(model.manufacturer))

const baseOf = (id) => bases.get(id) ?? byId.get(id)

// its own and its market variants'
const marketsOf = (model) => [...model.markets, ...model.variants.flatMap(({ markets }) => markets)]

// The model's market variant sold in `market`, where it has one
const soldIn = (model, market) => {
  const variant = market && model.variants.find(({ markets }) => markets.includes(market))
  return variant ? byId.get(variant.id) : model
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
    (!params.handlebar_type || model.handlebar_type === params.handlebar_type) &&
    (!params.target_riders || ridersOf(model) === params.target_riders) &&
    (!params.frame_material || comparison?.fields.frame_material?.[model.position] === params.frame_material) &&
    (!params.market || inMarket(model, params.market, params.market_scope)) &&
    (yearMin == null || model.sortYear >= yearMin) &&
    (yearMax == null || (model.first_year ?? 0) <= yearMax) &&
    ((priceMin == null && priceMax == null) || (model.msrp_cents > 0 &&
      (priceMin == null || model.msrp_cents >= priceMin * 100) && (priceMax == null || model.msrp_cents <= priceMax * 100)))
}

// evc/out-of-class is the catalog's own marker, as a model with no classified mode is unknown rather than out of class,
// and evc/out-of-class/us/ca its marker for one in no class in that state alone, where it's out of class rather than the US
// classes it carries. A state's class matches the models carrying its groups
function propelled ({ electric, e_vehicle_classifications: carried = [] }, propulsion, jurisdiction) {
  if (propulsion === '0' || propulsion === '1') return electric === (propulsion === '1')
  const id = propulsion.replace(/^class-/, 'evc/us/class-')
  if (/^evc\/(out-of-class|us\/class-\d)$/.test(id) && carried.includes(`evc/out-of-class/us/${jurisdiction?.toLowerCase()}`)) return id === 'evc/out-of-class'
  return [id, ...(classifications[id]?.groups ?? [])].some((classification) => carried.includes(classification))
}

self.onmessage = async ({ data: { id, type, ...args } }) => {
  try {
    self.postMessage({ id, result: await { start, load, comparison: compare, search, featured, rotate, group, vehicles, displays, similar }[type](args) })
  } catch (error) {
    self.postMessage({ id, error: error.message })
  }
}
