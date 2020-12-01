import React from "react";
import ReactDOM from "react-dom";
import ErrorBoundary from "@honeybadger-io/react";
import MultiSerialSearch from "../scripts/multi_serial_search/MultiSerialSearch";
import honeybadger from "../scripts/utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("multi-serial-search");

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <MultiSerialSearch />
    </ErrorBoundary>,
    el
  );
});
