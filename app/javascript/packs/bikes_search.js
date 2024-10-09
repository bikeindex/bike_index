import React from "react";
import ReactDOM from "react-dom";

import ErrorBoundary from "@honeybadger-io/react";

import BikeSearches from "../scripts/bikes_search/bike_searches";
import honeybadger from "../scripts/utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-secondary-searches");
  if (!el) {
    return;
  }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <BikeSearches interpretedParams={window.interpreted_params} />
    </ErrorBoundary>,
    el
  );
});
