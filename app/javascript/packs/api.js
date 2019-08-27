/*
  Private
*/

const url = urn => [process.env.BASE_URL, urn].join("/");

const serialSearchUrl = serial => url(`api/v2/bikes_search?serial=${serial}`);

const fuzzySearchUrl = serial =>
  url(`api/v2/bikes_search/close_serials?serial=${serial}`);

const serialExternalSearchUrl = serial =>
  url(`api/v3/search/external_registries?serial=${serial}`);

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

export { fetchSerialResults, fetchFuzzyResults, fetchSerialExternalSearch };
