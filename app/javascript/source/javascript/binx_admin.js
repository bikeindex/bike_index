import * as log from "loglevel";
if (process.env.NODE_ENV != "production") log.setLevel("debug");
import moment from "moment-timezone";

window.BinxAdmin = class BinxAdmin {
  init() {
    // If there is an element on the page with id pageContainerFluid, make the page container full width
    if ($("#pageContainerFluid").length) {
      $("#admin-content > .receptacle").css("max-width", "100%");
    } else {
      // Also, make full-screen-table receptacle max-width
      $(".full-screen-table")
        .parents(".receptacle")
        .css("max-width", "100%");
    }
  }
};

$( document ).ready(function() {
    $("select#graph_date_option_choice").on("click", e => {
      e.preventDefault();
      console.log($(this))
    })
});