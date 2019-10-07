import React from "react";
import ReactDOM from "react-dom";
import ErrorBoundary from "@honeybadger-io/react";
import PartialSerialSearch from "./components/PartialSerialSearch";
import honeybadger from "../utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("js-partial-serial-search");

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
    <PartialSerialSearch interpretedParams={window.interpreted_params} />
    </ErrorBoundary>,
    el
  );
});
