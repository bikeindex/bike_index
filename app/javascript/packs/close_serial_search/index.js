import React from "react";
import ReactDOM from "react-dom";
import ErrorBoundary from "@honeybadger-io/react";
import CloseSerialSearch from "./components/CloseSerialSearch";
import honeybadger from "../utils/honeybadger";

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
