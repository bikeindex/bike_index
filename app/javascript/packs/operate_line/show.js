import log from "../../utils/log";
const Handlebars = require("handlebars");
import "bootstrap";

import TimeParser from "../../utils/time_parser.js";
import EnableEscapeForModals from "../../utils/enable_escape_for_modals.js";

const updateCustomer = function (customerId, status) {
  log.debug(customerId, status);
};

const renderNextCustomers = function (customers) {
  document.getElementById(
    "nextTicketsToHelp"
  ).innerHTML = window.customerTemplate(customers);
};

document.addEventListener("DOMContentLoaded", () => {
  const el = document.getElementById("operateLineCustomerTemplate");
  if (!el) {
    return;
  }

  const customerTemplateScript = document.getElementById(
    "operateLineCustomerTemplate"
  ).innerHTML;

  window.customerTemplate = Handlebars.compile(customerTemplateScript);

  renderNextCustomers(window.customers);

  $("#organized-virtual-line-wrapper").on(
    "click",
    ".btn-customer-update",
    (e) => {
      e.preventDefault();
      const $target = $(e.target);
      updateCustomer(
        $target.attr("data-customerid"),
        $target.attr("data-updatestatus")
      );
    }
  );
});

// separate jQuery things that require readiness
$(document).ready(function () {
  EnableEscapeForModals();
});
