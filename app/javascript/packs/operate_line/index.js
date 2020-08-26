import React from "react";
import ReactDOM from "react-dom";

import ErrorBoundary from "@honeybadger-io/react";

import Customer from "./components/customer";
import honeybadger from "../../utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("simpleViewJs");
  if (!el) {
    return;
  }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <Customer />
    </ErrorBoundary>,
    el
  );
});
