export const LISTS = ['primary_activity', 'manufacturer', 'vehicle_type']
export const SINGLES = ['suspension', 'model_configuration', 'frame_material', 'handlebar_type', 'market']
export const RANGES = ['year_min', 'year_max', 'price_min', 'price_max']
// Whether the search shows: asked for, or with anything but a single model picked - a classification's card counts, as
// its chip is in the search - as a link straight to one opens it. Pages::Bikebook::Show::Component#placeholder_class mirrors it
export const searching = (url) => {
  const [models, classifications] = ['vehicle_models', 'classifications'].map((name) => String(url.searchParams.get(name) ?? '').split(',').filter(Boolean))
  return url.searchParams.has('search') || models.length !== 1 || classifications.length > 0
}

// `filters` with a range given backwards, 2026 to 2020, the way round it was meant
export const ordered = (filters) => ['year', 'price'].reduce((each, name) => {
  const [min, max] = [`${name}_min`, `${name}_max`]
  return each[min] && each[max] && Number(each[min]) > Number(each[max]) ? { ...each, [min]: each[max], [max]: each[min] } : each
}, filters)

export const NARROWING = [...LISTS, ...SINGLES, ...RANGES, 'electric', 'market_scope', 'jurisdiction']
export const FILTERS = [...NARROWING, 'sort', 'year_dir', 'price_dir']

// to_query: keys sorted and CGI-escaped, blank values dropped, commas and slashes left readable
export const toQuery = (params) => {
  const cgiEscape = (text) => encodeURIComponent(text).replace(/[!'()*]/g, (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`)
    .replace(/%20/g, '+').replace(/%2[CF]/g, decodeURIComponent)
  return Object.keys(params).filter((key) => String(params[key] ?? '').trim() !== '').sort()
    .map((key) => `${cgiEscape(key)}=${cgiEscape(params[key])}`).join('&')
}
