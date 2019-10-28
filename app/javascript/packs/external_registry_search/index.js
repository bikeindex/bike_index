import React from "react";
import ReactDOM from "react-dom";
import ErrorBoundary from "@honeybadger-io/react";
import ExternalRegistrySearch from "./components/ExternalRegistrySearch";
import honeybadger from "../utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-external-registry-search");
  if (!el) { return; }

  // Query for the raw serial when searching external registries.
  // On the server side we'll query each external registry for both the raw
  // and normalized forms.
  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>

    <ExternalRegistrySearch
      stolenness={window.interpreted_params.stolenness}
      query={window.interpreted_params.query}
      serial={window.interpreted_params.raw_serial}
     />
    </ErrorBoundary>,
    el
  );
});
