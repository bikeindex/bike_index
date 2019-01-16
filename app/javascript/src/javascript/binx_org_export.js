import * as log from "loglevel";
if (process.env.NODE_ENV != "production") log.setLevel("debug");
import moment from "moment-timezone";

window.BinxAppOrgExport = class BinxAppOrgExport {
  init() {
    let body_id = document.getElementsByTagName("body")[0].id;

    if (body_id == "organized_exports_new") {
      binxAppOrgExport.initNewForm();
    } else {
      binxAppOrgExport.reloadIfUnfinished();
    }
  }

  initNewForm() {
    // make the datetimefield expand, set the time
    $(".datetimefield-expander").on("click", e => {
      e.preventDefault();
      let $parent = $(e.target).parents(".form-group");
      $parent.find(".datetimefield-expander").slideUp("fast", function() {
        $parent.find(".datetimefield-fields").slideDown("fast");
        $parent
          .find("input[type='datetime-local']")
          .val(moment().format("YYYY-MM-DDTHH:mm"));
      });
    });
    // make the datetimefield collapse, remove the time
    $(".datetimefield-collapser").on("click", e => {
      e.preventDefault();
      let $parent = $(e.target).parents(".form-group");
      $parent.find(".datetimefield-fields").slideUp("fast", function() {
        $parent.find(".datetimefield-expander").slideDown("fast");
        $parent.find("input[type='datetime-local']").val("");
      });
    });

    // Show avery
    binxAppOrgExport.showOrHideNonAvery();
    // and on future changes, trigger the update
    $("#export_avery_export").on("change", e => {
      binxAppOrgExport.showOrHideNonAvery();
    });
  }

  showOrHideNonAvery() {
    let isAvery = $("#export_avery_export").is(":checked");
    if (isAvery) {
      $(".hiddenOnAveryExport").slideUp("fast");
    } else {
      $(".hiddenOnAveryExport")
        .slideDown("fast")
        .css("display", "flex");
    }
  }

  reloadIfUnfinished() {
    if (!$("#exportProgress").hasClass("finished")) {
      // Reload the page after 2 seconds unless the export is more than 5 minutes old - at which point we assume something is broken
      let created = parseInt($("#exportProgress").attr("data-createdat"));
      if (moment().unix() - created < 300) {
        window.setTimeout(() => {
          location.reload(true);
        }, 5000);
      }
    }
  }
};
