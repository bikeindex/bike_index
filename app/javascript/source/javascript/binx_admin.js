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
    if (window.location.href.match('\\admin/graphs')){
      this.initGraph()
    };
  }

  initGraph() {
    $("select#graph_date_option_choice").on("change", e => {
      e.preventDefault()
      if ($("select#graph_date_option_choice")[0].value === "custom") {
        $("#calendar-box").slideDown()
      }
      else {
        $("#calendar-box").slideUp()
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
  }
};