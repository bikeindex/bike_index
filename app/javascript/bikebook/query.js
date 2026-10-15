export const LISTS = ['primary_activity', 'manufacturer', 'vehicle_type']
export const SINGLES = ['suspension', 'model_configuration', 'market']
export const RANGES = ['year_min', 'year_max', 'price_min', 'price_max']
export const FILTERS = [...LISTS, ...SINGLES, ...RANGES, 'electric', 'jurisdiction', 'year_dir', 'price_dir']

// to_query: keys sorted and CGI-escaped, blank values dropped, commas and slashes left readable
export const toQuery = (params) => {
  const cgiEscape = (text) => encodeURIComponent(text).replace(/[!'()*]/g, (character) => `%${character.charCodeAt(0).toString(16).toUpperCase()}`)
    .replace(/%20/g, '+').replace(/%2[CF]/g, decodeURIComponent)
  return Object.keys(params).filter((key) => String(params[key] ?? '').trim() !== '').sort()
    .map((key) => `${cgiEscape(key)}=${cgiEscape(params[key])}`).join('&')
}
