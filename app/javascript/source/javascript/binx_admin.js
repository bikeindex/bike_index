import * as log from "loglevel";
if (process.env.NODE_ENV != "production") log.setLevel("debug");
import moment from "moment-timezone";

window.BinxAdmin = class BinxAdmin {
  // Should be inside init() but having a hard time with errors
  // initGraph() {
  //   $("select#graph_date_option_choice").on("change", e => {
  //     e.preventDefault()
  //     if ($("select#graph_date_option_choice")[0].value === "custom") {
  //       $(".clearfix").slideDown()
  //     }
  //     else {
  //       $(".clearfix").slideUp()
  //       let $this = $('#start_at')
  //       let graphSelected = $("select#graph_date_option_choice")[0].value.split(",")
  //       let amount = Number(graphSelected[0])
  //       let unit = graphSelected[1]
  //       $this.val(
  //         moment()
  //           .subtract(amount, unit)
  //           .format("YYYY-MM-DDTHH:mm")
  //         )
  //     }
  //   });
  // }

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
    // Should be it's own function but I'm having a hard time, keep getting undefined function when trying to create it elsewhere
    if (window.location.href.match('\\admin/graphs')){
      $("select#graph_date_option_choice").on("change", e => {
        e.preventDefault()
        if ($("select#graph_date_option_choice")[0].value === "custom") {
          $(".clearfix").slideDown()
        }
        else {
          $(".clearfix").slideUp()
          let $this = $('#start_at')
          let graphSelected = $("select#graph_date_option_choice")[0].value.split(",")
          let amount = Number(graphSelected[0])
          let unit = graphSelected[1]
          $this.val(
            moment()
              .subtract(amount, unit)
              .format("YYYY-MM-DDTHH:mm")
            )
        }
      });
    };
  }
};