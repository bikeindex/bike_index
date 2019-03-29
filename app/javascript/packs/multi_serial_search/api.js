/* eslint no-shadow: 0 */

/*
  Private
*/

const url = urn => (process.env.RAILS_ENV === 'development'
  ? `http://localhost:3001/${urn}`
  : `https://bikeindex.org/${urn}`);

const serialSearchUrl = serial => url(
  `api/v1/bikes?multi_serial_search=true&serial=${serial}`,
);

const fuzzySearchUrl = serial => url(
  `api/v1/bikes/close_serials?multi_serial_search=true&serial=${serial}`,
);

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

export {
  fetchSerialResults,
  fetchFuzzyResults,
};
