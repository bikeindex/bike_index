import React from "react";
import ReactDOM from "react-dom";

import ErrorBoundary from "@honeybadger-io/react";

import SecondarySearches from "../scripts/bikes_search/SecondarySearches";
import honeybadger from "../scripts/utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-secondary-searches");
  if (!el) {
    return;
  }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <SecondarySearches interpretedParams={window.interpreted_params} />
    </ErrorBoundary>,
    el
  );
});
