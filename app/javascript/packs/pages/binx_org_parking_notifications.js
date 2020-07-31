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

  // Below here is just stuff for rendering the table rows

  statusSpan(status) {
    const statusString = status
      .replace("_", " ")
      .replace("otherwise", "")
      .trim();
    const statusClass =
      status === "current"
        ? "text-success"
        : ["retrieved", "resolved_otherwise"].includes(status)
        ? "text-info"
        : ["removed", "impounded"].includes(status)
        ? "text-danger"
        : "";

    return `<span class="${statusClass}">${statusString}</span>`;
  }

  bikeLink(record) {
    const bikeCellUrl = `/bikes/${record.bike.id}`;
    return `<a href="${bikeCellUrl}">${record.bike.title} ${
      record.unregistered_bike
        ? '<em class="text-warning small"> unregistered</em>'
        : ""
    }</a>`;
  }

  // returns a link to the impound record, if it's impounded
  // returns a span if it is resolved but not impounded
  retrievedAtEl(record) {
    if (record.impound_record_id === null) {
      return record.resolved_at
        ? `<span class="convertTime preciseTime">${record.resolved_at}</span>`
        : "";
    }
    return `<a href="/o/${window.passiveOrganizationId}/impound_records/pkey-${record.impound_record_id}" class="convertTime">${record.resolved_at}</a>`;
  }

  mainTableCell(record) {
    const showCellUrl = `${location.pathname}/${record.id}`;

    return `<a href="${showCellUrl}" class="convertTime">${
      record.created_at
    }</a> <span class="extended-col-info small"> - <em>${
      record.kind_humanized
    }</em> - by ${record.user_display_name}<strong>${
      record.notification_number > 1
        ? "- notification #" + record.notification_number
        : ""
    }</strong></span> <span class="extended-col-info d-block">${this.bikeLink(
      record
    )}
    <em class="small status-cell ml-2">
      ${this.statusSpan(record.status)}${
      record.resolved_at ? `: ${this.retrievedAtEl(record)}` : ""
    }
    </em></span>`;
  }

  tableRowForRecord(record) {
    if (typeof record !== "object" || typeof record.id !== "number") {
      return "";
    }

    return `<tr class="record-row" data-recordid="${
      record.id
    }"><td class="map-cell"><a>↑</a></td><td>${this.mainTableCell(record)}
    </td><td class="hidden-sm-cells">${this.bikeLink(
      record
    )}</td><td class="hidden-sm-cells"><em>${
      record.kind_humanized
    }</em></td><td class="hidden-sm-cells">${
      record.user_display_name
    }</td><td class="hidden-sm-cells">${
      record.notification_number > 1 ? record.notification_number : ""
    }</td><td class="hidden-sm-cells status-cell">${this.statusSpan(
      record.status
    )}</td><td class="hidden-sm-cells">${this.retrievedAtEl(record)}</td>
    <td class="multiselect-cell table-cell-check collapse"><input type="checkbox" name="ids[${
      record.id
    }]" id="ids_${record.id}" value="${record.id}"></td>
    `;
  }
}
