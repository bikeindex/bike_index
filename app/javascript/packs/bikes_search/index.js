import React from "react";
import ReactDOM from "react-dom";

import ErrorBoundary from "@honeybadger-io/react";

import CloseSerialSearch from "./components/CloseSerialSearch";
import ExternalRegistrySearch from "./components/ExternalRegistrySearch";
import PartialSerialSearch from "./components/PartialSerialSearch";
import honeybadger from "../utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-partial-serial-search");
  if (!el) { return; }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <PartialSerialSearch interpretedParams={window.interpreted_params} />
    </ErrorBoundary>,
    el
  );
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-close-serial-search");
  if (!el) { return; }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
    <CloseSerialSearch interpretedParams={window.interpreted_params} />
    </ErrorBoundary>,
    el
  );
});

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-external-registry-search");
  if (!el) { return; }

  // Query for the raw serial when searching external registries.
  // On the server side we'll query each external registry for both the raw
  // and normalized forms.
  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>

    <ExternalRegistrySearch interpretedParams={window.interpreted_params} />
    </ErrorBoundary>,
    el
  );
});
