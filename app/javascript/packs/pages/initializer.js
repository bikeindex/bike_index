import log from "../utils/log";
import TimeParser from "../utils/time_parser.js";
import BinxMapping from "./binx_mapping.js";
import WalkrightupCustomer from "./walkrightup/customer.js";
import BinxAdmin from "./admin/binx_admin.js";
import BinxAppOrgExport from "./binx_org_export.js";
import BinxAppOrgLines from "./binx_org_lines.js";
import BinxAppOrgParkingNotifications from "./binx_org_parking_notifications.js";
import BinxAppOrgImpoundRecords from "./binx_org_impound_records.js";
import BinxAppOrgBikes from "./binx_org_bikes.js";
import BinxAppOrgUserForm from "./binx_org_user_form";
import PeriodSelector from "../utils/period_selector.js";

window.binxApp || (window.binxApp = {});

binxApp.enableFilenameForUploads = function () {
  $("input.custom-file-input[type=file]").on("change", function (e) {
    // The issue is that the files list isn't actually an array. So we can't map it
    let files = [];
    let i = 0;
    while (i < e.target.files.length) {
      files.push(e.target.files[i].name);
      i++;
    }
    $(this).parent().find(".custom-file-label").text(files.join(", "));
  });
};

// I've made the choice to have classes' first letter capitalized
// and make the instance of class (which I'm storing on window) the same name without the first letter capitalized
// I'm absolutely sure there is a best practice that I'm ignoring, but just doing it for now.
$(document).ready(function () {
  window.timeParser = new TimeParser();
  window.timeParser.localize();
  log.debug("fasdfasdfsfsdf");
  // Period selector
  if ($("#timeSelectionBtnGroup").length) {
    window.periodSelector = PeriodSelector();
    window.periodSelector.init();
  }
  // Load admin, whatever
  if ($("#admin-content").length > 0) {
    const binxAdmin = BinxAdmin();
    binxAdmin.init();
  }

  // Load admin, whatever
  if ($("#customer-virtual-line-wrapper").length > 0) {
    window.walkrightupCustomer = new WalkrightupCustomer();
    walkrightupCustomer.init();
  }
  // Load the page specific things
  const bodyId = document.getElementsByTagName("body")[0].id;
  // If we're trying to target all pages from a controller ;)
  const pageControllerId = bodyId.replace(/_[^_]*$/, "");
  if ("organized_lines" == pageControllerId) {
    window.binxAppOrgLines = new BinxAppOrgLines();
    binxAppOrgLines.init();
  } else if ("organized_parking_notifications" == pageControllerId) {
    window.binxAppOrgParkingNotifications = new BinxAppOrgParkingNotifications();
    binxAppOrgParkingNotifications.init();
  } else if ("organized_exports" === pageControllerId) {
    window.binxAppOrgExport = new BinxAppOrgExport();
    binxAppOrgExport.init();
  } else if (bodyId === "organized_bikes_index") {
    const binxAppOrgBikes = BinxAppOrgBikes();
    binxAppOrgBikes.init();
  } else if ("organized_impound_records" === pageControllerId) {
    window.binxAppOrgImpoundRecords = new BinxAppOrgImpoundRecords();
    binxAppOrgImpoundRecords.init();
  }
  // This can be new, edit, create or update, so just checking for the element
  if ($("#multipleUserSelect").length) {
    const binxAppOrgUserForm = BinxAppOrgUserForm();
    binxAppOrgUserForm.init();
  }
});
