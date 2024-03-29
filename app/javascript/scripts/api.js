/*
  Private
*/

const url = urn => [process.env.BASE_URL, urn].join('/')

const serialSearchUrl = serial => url(`api/v2/bikes_search?serial=${serial}`)

const fuzzySearchUrl = serial =>
  url(`api/v2/bikes_search/close_serials?serial=${serial}`)

const partialMatchSerialSearchUrl = params => {
  const query = queryString(params)
  return url(`api/v3/search/serials_containing?${query}`)
}

const serialCloseSearchUrl = params => {
  const query = queryString(params)
  return url(`api/v3/search/close_serials?${query}`)
}

const serialExternalSearchUrl = ({ serial }) => {
  const query = queryString({ serial })
  return url(`api/v3/search/external_registries?${query}`)
}

const parseLinkHeader = linkHeader => {
  if (!linkHeader) {
    return null
  }
  const linkHeadersArray = linkHeader
    .split(', ')
    .map(header => header.split('; '))
  const linkHeadersMap = linkHeadersArray.map(header => {
    const thisHeaderRel = header[1].replace(/"/g, '').replace('rel=', '')
    const thisHeaderUrl = header[0].slice(1, -1)
    return [thisHeaderRel, thisHeaderUrl]
  })
  return Object.fromEntries(linkHeadersMap)
}

const request = async url => {
  const resp = await fetch(url)
  let result = await resp.json()

  result.total = resp.headers.get('Total')
  result.link = parseLinkHeader(resp.headers.get('Link'))
  return result
}

const queryString = (passedParams = {}) => {
  return Object.keys(passedParams)
    .map(k => `${k}=${passedParams[k]}`)
    .join('&')
}

/*
  Public
*/

const fetchSerialResults = serial => {
  const url = serialSearchUrl(serial)
  return request(url)
}

const fetchFuzzyResults = serial => {
  const url = fuzzySearchUrl(serial)
  return request(url)
}

const fetchPartialMatchSearch = interpretedParams => {
  const url = partialMatchSerialSearchUrl(interpretedParams)
  return request(url)
}

const fetchSerialCloseSearch = interpretedParams => {
  const url = serialCloseSearchUrl(interpretedParams)
  return request(url)
}

const fetchSerialExternalSearch = ({ raw_serial }) => {
  const url = serialExternalSearchUrl({ serial: raw_serial })
  return request(url)
}

export default {
  fetchSerialResults,
  fetchFuzzyResults,
  fetchSerialExternalSearch,
  fetchSerialCloseSearch,
  fetchPartialMatchSearch
}
