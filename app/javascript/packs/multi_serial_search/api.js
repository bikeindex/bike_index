/* TODO: put some of the private implementation into a utility helper */

/*
  Private
*/

const isDevelopment = process.env.RAILS_ENV === 'development';

const serialSearchUrl = serial => {
  const urn = `api/v1/bikes?multi_serial_search=true&serial=${serial}`;
  return isDevelopment
    ? `http://localhost:3001/${urn}`
    : `https://bikeindex.org/${urn}`;
};

const request = async url => {
  const resp = await fetch(url);
  const json = await resp.json();
  return json;
};

/*
  Public
*/

const fetchSerialResults = async serial => {
  const url = serialSearchUrl(serial);
  const results = await request(url);
  return results;
};

export { fetchSerialResults };
