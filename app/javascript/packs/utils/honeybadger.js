/* eslint no-console: 0 */

import Honeybadger from 'honeybadger-js';

const config = {
  api_key: process.env.HONEYBADGER_API_KEY,
  environment: process.env.RAILS_ENV,
};

const honeybadger = Honeybadger.configure(config);

Honeybadger.beforeNotify(notice => {
  if (!process.env.RAILS_ENV === 'development') return;
  console.error('<development> Honeybadger Error', notice);
});

export default honeybadger;
