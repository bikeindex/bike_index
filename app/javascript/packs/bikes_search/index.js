import React from "react";
import ReactDOM from "react-dom";

import ErrorBoundary from "@honeybadger-io/react";

import SecondarySearches from "./components/SecondarySearches";
import honeybadger from "../utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  var el = document.getElementById("js-secondary-searches");
  if (!el) { return; }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <SecondarySearches interpretedParams={window.interpreted_params} />
    </ErrorBoundary>,
    el)
});
