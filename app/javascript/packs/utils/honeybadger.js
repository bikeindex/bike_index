import Honeybadger from "honeybadger-js";
import log from "./log";

const environment = process.env.RAILS_ENV;

/* webpacker can't access this exported env */
const apiKey =
  environment === "production" ? process.env.HONEYBADGER_FRONTEND_API_KEY : "foo";

const config = {
  apiKey,
  environment: process.env.RAILS_ENV,
  disabled: environment !== "production"
};
const honeybadger = Honeybadger.configure(config);

Honeybadger.beforeNotify(notice => {
  if (environment === "development") {
    return log.debug("Error", notice);
  }
});
export default honeybadger;
