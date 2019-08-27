import React from "react";
import ReactDOM from "react-dom";
import ErrorBoundary from "@honeybadger-io/react";
import ExternalRegistrySearch from "./components/ExternalRegistrySearch";
import honeybadger from "../utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-external-registry-search");

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
    <ExternalRegistrySearch
      stolenness={window.interpreted_params.stolenness}
      query={window.interpreted_params.query}
      serial={window.interpreted_params.serial}
     />
    </ErrorBoundary>,
    el
  );
});
