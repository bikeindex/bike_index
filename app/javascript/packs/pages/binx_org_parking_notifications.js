import log from "../utils/log";
import BinxMapping from "./binx_mapping.js";
import BinxAppOrgParkingNotificationMapping from "./binx_org_parking_notification_mapping.js";

export default class BinxAppOrgParkingNotifications {
  init() {
    const bodyId = document.getElementsByTagName("body")[0].id;

    if (bodyId === "organized_parking_notifications_index") {
      this.initializeIndex();
    } else {
      this.initializeRepeatSubmit();
    }
  }

  initializeIndex() {
    window.binxMapping = new BinxMapping("parking_notifications");
    window.binxAppOrgParkingNotificationMapping = new BinxAppOrgParkingNotificationMapping();
    binxAppOrgParkingNotificationMapping.init();
    initializeRepeatSubmit();
  }

  initializeRepeatSubmit() {
    $("#sendRepeatOrRetrieveFields select").on("change", function(e) {
      var submitText =
        $("#sendRepeatOrRetrieveFields select").val() == "mark_retreived"
          ? "Resolve notification"
          : "Create notification";
      $("#sendRepeatOrRetrieveFields .btn").val(submitText);
    });
  }
}
