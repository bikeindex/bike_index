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
    if (window.location.href.match("\\admin/graphs")) {
      window.binxAdmin.setShownOption();
      window.binxAdmin.setState();
      this.initGraph();
    }
  }

  initGraph() {
    $("select#graph_date_option").on("change", e => {
      e.preventDefault();
      this.setState();
    });
  }

  startTimeSet() {
    let graphSelected = $("select#graph_date_option")[0].value.split(",");
    let amount = Number(graphSelected[0]);
    let unit = graphSelected[1];
    $("#start_at").val(
      moment()
        .subtract(amount, unit)
        .format("YYYY-MM-DDTHH:mm")
    );
  }

  slide(direction) {
    if (direction === "Up") {
      $(".calendar-box").slideUp();
    } else if (direction === "Down") {
      $(".calendar-box").slideDown();
    }
  }

  setState() {
    if ($("select#graph_date_option")[0].value === "custom") {
      this.slide("Down");
    } else {
      this.slide("Up");
      this.startTimeSet();
    }
  }
  queryParameters() {
    let result = {};
    let params = window.location.search.split(/\?|\&/);
    params.forEach(function(it) {
      if (it) {
        let param = it.split("=");
        result[param[0]] = param[1];
      }
    });
    return result;
  }
  setShownOption() {
    let choice = this.queryParameters().graph_date_option;
    if (choice === "1%Cdays") {
      $("select#graph_date_option")[0].value = "1,days";
    } else if (choice === "1%2Cweeks") {
      $("select#graph_date_option")[0].value = "1,weeks";
    } else if (choice === "1%2Cmonths") {
      $("select#graph_date_option")[0].value = "1,months";
    } else if (choice === "6%2Cmonths") {
      $("select#graph_date_option")[0].value = "6,months";
    } else if (choice === "1%2Cyears") {
      $("select#graph_date_option")[0].value = "1,years";
    }
  }
};
