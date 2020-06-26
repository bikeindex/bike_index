import log from "../utils/log";
import BinxMapping from "./binx_mapping.js";
import BinxAppOrgParkingNotificationMapping from "./binx_org_parking_notification_mapping.js";

export default class BinxAppOrgParkingNotifications {
  constructor() {
    this.indexView =
      document.getElementsByTagName("body")[0].id ===
      "organized_parking_notifications_index";
  }
  init() {
    if (this.indexView) {
      this.initializeIndex();
    } else {
      this.initializeRepeatSubmit();
    }
  }

  initializeIndex() {
    window.binxMapping = new BinxMapping("parking_notifications");
    window.binxAppOrgParkingNotificationMapping = new BinxAppOrgParkingNotificationMapping();
    binxAppOrgParkingNotificationMapping.init();
    this.initializeRepeatSubmit();
    // Call the existing coffeescript class that manages the bike searchbar
    new BikeIndex.BikeSearchBar();
  }

  initializeRepeatSubmit() {
    const indexView = this.indexView;
    $("#sendRepeatOrRetrieveFields select").on("change", function (e) {
      const pluralText = indexView ? "s" : "";
      const submitText =
        $("#sendRepeatOrRetrieveFields select").val() == "mark_retreived"
          ? "Resolve notification"
          : "Create notification";
      $("#sendRepeatOrRetrieveFields .btn").val(submitText + pluralText);
    });

    // We're letting bootstrap handle the collapsing of the row, make sure to not block
    $("#toggleSendRepeat").on("click", function (e) {
      $("#toggleSendRepeat").slideUp();
      $(".multiselect-cell").slideDown();
      return true;
    });

    $("#selectAllSelector").on("click", function (e) {
      e.preventDefault();
      window.toggleAllChecked = !window.toggleAllChecked;
      $(".multiselect-cell input").prop("checked", window.toggleAllChecked);
    });
  }
}
