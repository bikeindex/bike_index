import * as log from "loglevel";
if (process.env.NODE_ENV != "production") log.setLevel("debug");

window.BinxAppOrgExport = class BinxAppOrgExport {
  init() {
    // Show what should be shown
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
};
