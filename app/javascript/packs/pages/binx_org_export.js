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
    $(".field-expander").on("click", e => {
      e.preventDefault();
      let $parent = $(e.target).parents(".form-group");
      $parent.find(".field-expander").slideUp("fast", function() {
        $parent.find(".collapsed-fields").slideDown("fast");
        $parent.find("input[type='datetime-local']").val(
          moment()
            .startOf("day")
            .format("YYYY-MM-DDTHH:mm")
        );
      });
    });
    // make the datetimefield collapse, remove the time
    $(".field-collapser").on("click", e => {
      e.preventDefault();
      let $parent = $(e.target).parents(".form-group");
      $parent.find(".collapsed-fields").slideUp("fast", function() {
        $parent.find(".field-expander").slideDown("fast");
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
      $(".shownOnAveryExport")
        .slideDown("fast")
        .css("display", "flex");
    } else {
      $(".hiddenOnAveryExport")
        .slideDown("fast")
        .css("display", "flex");
      $(".shownOnAveryExport").slideUp("fast");
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
