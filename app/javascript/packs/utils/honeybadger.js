import Honeybadger from 'honeybadger-js';
import log from './log';

const config = {
  api_key: process.env.HONEYBADGER_API_KEY,
  environment: process.env.RAILS_ENV,
};

const honeybadger = Honeybadger.configure(config);

Honeybadger.beforeNotify(notice => {
  if (process.env.RAILS_ENV !== 'development') return;
  log.debug('<development> Honeybadger Error', notice);
});

export default honeybadger;
