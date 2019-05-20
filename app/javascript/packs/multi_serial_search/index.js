import React from "react";
import ReactDOM from "react-dom";
import ErrorBoundary from "@honeybadger-io/react";
import MultiSerialSearch from "./components/MultiSerialSearch";
import honeybadger from "../utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("multi-serial-search");

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <MultiSerialSearch />
    </ErrorBoundary>,
    el
  );
});
