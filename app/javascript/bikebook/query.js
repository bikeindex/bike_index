import { readably } from 'bikebook/replace_url'
import { vehicleIds } from 'bikebook/vehicle_models'

export const LISTS = ['primary_activity', 'manufacturer', 'vehicle_type']
export const SINGLES = ['suspension', 'model_configuration', 'frame_material', 'handlebar_type', 'market']
export const RANGES = ['year_min', 'year_max', 'price_min', 'price_max']
export const paramList = (url, name) => String(url.searchParams.get(name) ?? '').split(',').filter(Boolean)
// Whether the search shows: asked for, or with anything but a single model picked - a classification's card counts, as
// its chip is in the search - as a link straight to one opens it. Pages::Bikebook::Show::Component#placeholder_class mirrors it
export const searching = (url) => url.searchParams.has('search') || vehicleIds(url).length !== 1 || paramList(url, 'classifications').length > 0

// `filters` with a range given backwards, 2026 to 2020, the way round it was meant
export const ordered = (filters) => ['year', 'price'].reduce((each, name) => {
  const [min, max] = [`${name}_min`, `${name}_max`]
  return each[min] && each[max] && Number(each[min]) > Number(each[max]) ? { ...each, [min]: each[max], [max]: each[min] } : each
}, filters)

export const NARROWING = [...LISTS, ...SINGLES, ...RANGES, 'electric', 'market_scope', 'jurisdiction']
export const FILTERS = [...NARROWING, 'sort', 'year_dir', 'price_dir']

// to_query: keys sorted and CGI-escaped, blank values dropped, left readable
export const toQuery = (params) => {
  const cgiEscape = (text) => readably(encodeURIComponent(text).replace(/[!'()*]/g, (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`)
    .replace(/%20/g, '+'))
  return Object.keys(params).filter((key) => String(params[key] ?? '').trim() !== '').sort()
    .map((key) => `${cgiEscape(key)}=${cgiEscape(params[key])}`).join('&')
}

// Whether the page at `url` is of what the comparison adds, the similar models or a frame material
export const comparing = (url) => url.searchParams.get('similar') === '1' || url.searchParams.get('frame_material')
