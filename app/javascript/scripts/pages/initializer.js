import log from "../utils/log";
import TimeParser from "../utils/time_parser.js";
import BinxMapping from "./binx_mapping.js";
import BinxAdmin from "./admin/binx_admin.js";
import BinxAppOrgExport from "./binx_org_export.js";
import BinxAppOrgParkingNotifications from "./binx_org_parking_notifications.js";
import BinxAppOrgImpoundRecords from "./binx_org_impound_records.js";
import BinxAppOrgBikes from "./binx_org_bikes.js";
import BinxAppOrgUserForm from "./binx_org_user_form";
import PeriodSelector from "../utils/period_selector.js";

window.binxApp || (window.binxApp = {});

// I've made the choice to have classes' first letter capitalized
// and make the instance of class (which I'm storing on window) the same name without the first letter capitalized
// I'm absolutely sure there is a best practice that I'm ignoring, but just doing it for now.
$(document).ready(function () {
  if (!window.timeParser) { window.timeParser = new TimeParser() }
  window.timeParser.localize()
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

  // Load the page specific things
  const bodyId = document.getElementsByTagName("body")[0].id;
  // If we're trying to target all pages from a controller ;)
  const pageControllerId = bodyId.replace(/_[^_]*$/, "");
  if ("organized_parking_notifications" == pageControllerId) {
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
