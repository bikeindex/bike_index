import React from "react";
import ReactDOM from "react-dom";

import ErrorBoundary from "@honeybadger-io/react";

import BikeSearch from "./components/BikeSearch";
import ExternalRegistrySearchResult from "./components/ExternalRegistrySearchResult";
import honeybadger from "../utils/honeybadger";
import api from "../api";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-partial-serial-search");
  if (!el) { return; }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <BikeSearch
        interpretedParams={window.interpreted_params}
        fetchBikes={api.fetchPartialMatchSearch}
        componentName="PartialSerialSearch"
        headerDomId="js-partial-serial-search-header"
      />
    </ErrorBoundary>,
    el
  );
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-close-serial-search");
  if (!el) { return; }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <BikeSearch
        interpretedParams={window.interpreted_params}
        fetchBikes={api.fetchSerialCloseSearch}
        componentName="CloseSerialSearch"
        headerDomId="js-close-serial-search-header"
      />
    </ErrorBoundary>,
    el
  );
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-external-registry-search");
  if (!el) { return; }

  const { stolenness, query, serial } = window.interpreted_params;
  if (stolenness === "non" || query || !serial) { return; }

  // Query for the raw serial when searching external registries.
  // On the server side we'll query each external registry for both the raw
  // and normalized forms.
  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <BikeSearch
        interpretedParams={window.interpreted_params}
        fetchBikes={api.fetchSerialExternalSearch}
        componentName="ExternalRegistrySearch"
        headerDomId="js-external-registry-search-header"
        resultComponent={ExternalRegistrySearchResult}
      />
    </ErrorBoundary>,
    el
  );
});
