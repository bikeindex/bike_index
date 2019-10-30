/*
  Private
*/

const url = urn => [process.env.BASE_URL, urn].join("/");

const serialSearchUrl = serial =>
  url(`api/v2/bikes_search?serial=${serial}`);

const fuzzySearchUrl = serial =>
  url(`api/v2/bikes_search/close_serials?serial=${serial}`);

const serialExternalSearchUrl = serial =>
  url(`api/v3/search/external_registries?serial=${serial}`);

const serialCloseSearchUrl = ({serial, stolenness, location, query }) => {
  const params = {};
  if (serial) { params.serial = serial; }
  if (stolenness) { params.stolenness = stolenness; }
  if (location) { params.location = location; }
  if (query) { params.query = query; }
  const queryString = Object.keys(params).map(k => `${k}=${params[k]}`).join("&");
  return url(`api/v3/search/close_serials?${queryString}`);
}

const request = async url => {
  const resp = await fetch(url);
  const json = await resp.json();
  return json;
};

/*
  Public
*/

const fetchSerialResults = serial => {
  const url = serialSearchUrl(serial);
  return request(url);
};

const fetchFuzzyResults = serial => {
  const url = fuzzySearchUrl(serial);
  return request(url);
};

const fetchSerialExternalSearch = serial => {
  const url = serialExternalSearchUrl(serial);
  return request(url);
}

const fetchSerialCloseSearch = interpretedParams => {
  const url = serialCloseSearchUrl(interpretedParams);
  return request(url);
}

export {
  fetchSerialResults,
  fetchFuzzyResults,
  fetchSerialExternalSearch,
  fetchSerialCloseSearch,
};
