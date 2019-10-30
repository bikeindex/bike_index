import React from "react";
import ReactDOM from "react-dom";

import ErrorBoundary from "@honeybadger-io/react";

import BikeSearch from "./components/BikeSearch";
import ExternalRegistrySearchResult from "./components/ExternalRegistrySearchResult";
import honeybadger from "../utils/honeybadger";
import api from "../api";

document.addEventListener("DOMContentLoaded", () => {
  const containerId = "js-partial-serial-search";
  const el = document.getElementById(containerId);
  if (!el) { return; }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <BikeSearch
        interpretedParams={window.interpreted_params}
        fetchBikes={api.fetchPartialMatchSearch}
        searchName="PartialSerialSearch"
        headerDomId={`${containerId}-header`}
      />
    </ErrorBoundary>,
    el
  );
});

document.addEventListener("DOMContentLoaded", () => {
  const containerId = "js-close-serial-search";
  const el = document.getElementById(containerId);
  if (!el) { return; }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <BikeSearch
        interpretedParams={window.interpreted_params}
        fetchBikes={api.fetchSerialCloseSearch}
        searchName="CloseSerialSearch"
        headerDomId={`${containerId}-header`}
      />
    </ErrorBoundary>,
    el
  );
});

document.addEventListener("DOMContentLoaded", () => {
  const containerId ="js-external-registry-search";
  const el = document.getElementById(containerId);
  if (!el) { return; }

  // Only search external registries if looking for
  // stolen/all bikes with no query
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
        searchName="ExternalRegistrySearch"
        headerDomId={`${containerId}-header`}
        resultComponent={ExternalRegistrySearchResult}
      />
    </ErrorBoundary>,
    el
  );
});
