import React from "react";
import ReactDOM from "react-dom";

import ErrorBoundary from "@honeybadger-io/react";

import NextCustomers from "./components/next_customers";
import honeybadger from "../../utils/honeybadger";

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("simpleViewJs");
  if (!el) {
    return;
  }

  ReactDOM.render(
    <ErrorBoundary honeybadger={honeybadger}>
      <NextCustomers />
    </ErrorBoundary>,
    el
  );
});
