import log from "../utils/log";
import _ from "lodash";

export default class BinxAppOrgParkingNotifications {
  constructor() {
    this.fetchedRecords = false;
    this.mapReady = false;
    this.listRendered = false;
    this.mapRendered = false;
    this.records = [];
  }

  init() {
    // load the maps API
    binxMapping.loadMap("binxAppOrgParkingNotifications.mapOrganizedRecords");
    this.fetchRecords([["per_page", 100]]);

    // On period update, fetch records
    const fetchRecords = this.fetchRecords;
    $("#timeSelectionCustom").on("submit", e => {
      fetchRecords();
      return false;
    });
    $("#timeSelectionBtnGroup .btn").on("click", e => {
      fetchRecords();
      return true;
    });

    // Call the existing coffeescript class that manages the bike searchbar
    new BikeIndex.BikeSearchBar();
  }

  fetchRecords(opts = []) {
    // Use the period selector urlParams - which will use the current period
    let urlParams = window.periodSelector.urlParamsWithNewPeriod();

    for (const param of opts) {
      urlParams.delete(param[0]); // remove any matching parameters
      urlParams.append(param[0], param[1]);
    }

    // Update the address bar to include the current parameters
    history.replaceState(
      {},
      "",
      `${location.pathname}?${urlParams.toString()}`
    );

    let url = `${location.pathname}?${urlParams.toString()}`;
    log.debug("fetching notifications: " + url);

    // Update the bike search panel to get specific bikes
    $("#period").val(urlParams.get("period"));
    $("#start_time").val(urlParams.get("start_time"));
    $("#end_time").val(urlParams.get("end_time"));
    // Using ajax here instead of fetch because we're relying on the cookies for auth for now
    $.ajax({
      type: "GET",
      dataType: "json",
      url: url,
      success(data, textStatus, jqXHR) {
        binxAppOrgParkingNotifications.fetchedRecords = true;
        binxAppOrgParkingNotifications.renderOrganizedRecords(
          data.parking_notifications
        );
      },
      error(data, textStatus, jqXHR) {
        binxAppOrgParkingNotifications.fetchedRecords = true;
        log.debug(data);
      }
    });
  }

  // Grabs the visible markers, looks up the records from them and returns that list
  visibleRecords() {
    return binxMapping.markersInViewport().map(marker => {
      return this.records.find(record => marker.binxId == record.id);
    });
  }

  // this loops and calls itself again if we haven't finished rendering the map and the records
  mapOrganizedRecords() {
    // if we have already rendered the mapRendered, then we're done!
    if (binxAppOrgParkingNotifications.mapRendered) {
      return true;
    }
    if (binxMapping.googleMapsLoaded()) {
      if (!binxAppOrgParkingNotifications.mapReady) {
        binxMapping.render(
          window.pageInfo.map_center_lat,
          window.pageInfo.map_center_lng
        );
        binxAppOrgParkingNotifications.mapReady = true;
      }
      // If the record list is rendered, it means we could be finished rendering!
      // Otherwise we haven't finished rendering and we need to loop this method
      if (binxAppOrgParkingNotifications.listRendered) {
        // The records are loaded, so process the records into markers
        binxAppOrgParkingNotifications.addMarkerPointsForRecords(
          binxAppOrgParkingNotifications.records
        );
        // Then render the points
        return binxAppOrgParkingNotifications.inititalizeMapMarkers();
      }
    }
    // call this again in .5 seconds, unless we returned prematurely (because things have rendered)
    log.debug("looping mapOrganizedRecords");
    setTimeout(binxAppOrgParkingNotifications.mapOrganizedRecords, 500);
  }

  // When the link button is clicked on the table, scroll up to the map and open the applicable marker
  addTableMapLinkHandler() {
    $("#recordsTable").on("click", ".map-cell a", e => {
      e.preventDefault();
      let recordId = parseInt(
        $(e.target)
          .parents("tr")
          .attr("data-recordid"),
        10
      );
      if (isNaN(recordId)) {
        return window.BikeIndexAlerts.add(
          "error",
          "Unable to find that record!"
        );
      }
      let record = _.find(binxAppOrgParkingNotifications.records, function(
        record
      ) {
        return recordId == record.id;
      });
      let marker = _.find(binxMapping.markersRendered, function(marker) {
        return recordId == marker.binxId;
      });
      binxMapping.openInfoWindow(marker, recordId, record);
      $("body, html").animate(
        {
          scrollTop: $(".organized-records #map").offset().top - 60 // 60px offset
        },
        "fast"
      );
    });
  }

  inititalizeMapMarkers() {
    binxMapping.addMarkers({ fitMap: true });
    this.mapRendered = true;
    // Add a trigger to the map when the viewport changes (after it has finished moving)
    google.maps.event.addListener(binxMap, "idle", function() {
      // This is grabbing the markers in viewport and logging the ids for them.
      // We actually need to rerender the the marker table
      log.debug("rerendering table because map");
      binxAppOrgParkingNotifications.renderRecordsTable(
        binxAppOrgParkingNotifications.visibleRecords()
      );
    });
    this.addTableMapLinkHandler();
  }

  tableRowForRecord(record) {
    if (typeof record !== "object" || typeof record.id !== "number") {
      return "";
    }
    const showCellUrl = `${location.pathname}/${record.id}`;
    const bikeCellUrl = `/bikes/${record.bike.id}`;
    const bikeLink = `<a href="${bikeCellUrl}">${record.bike.title}</a>`;
    const impoundLink =
      record.impund_record_id !== undefined
        ? `<a href="${record.impund_record_id}" class="convertTime">${
            record.impund_record_at
          }</a>`
        : "";
    return `<tr class="record-row" data-recordid="${
      record.id
    }"><td class="map-cell"><a>↑</a></td><td><a href="${showCellUrl}" class="convertTime">${
      record.created_at
    }</a> <span class="extended-col-info small"> - <em>${
      record.kind_humanized
    }</em> - by ${record.user_display_name}<strong>${
      record.repeat_number > 0 ? "- notification #" + record.repeat_number : ""
    }</strong></span> <span class="extended-col-info"><br>${bikeLink}
    ${impoundLink.length ? "<br>Impounded: " + impoundLink : ""}
    </span>
      </td><td class="hidden-sm-cells">${bikeLink}</td><td class="hidden-sm-cells"><em>${
      record.kind_humanized
    }</em></td><td class="hidden-sm-cells">${
      record.user_display_name
    }</td><td class="hidden-sm-cells">${
      record.repeat_number > 0 ? record.repeat_number : ""
    }</td><td class="hidden-sm-cells">${impoundLink}</td>`;
  }

  mapPopup(point) {
    let record = _.find(binxAppOrgParkingNotifications.records, [
      "id",
      point.id
    ]);
    let tableTop =
      '<table class="table table table-striped table-hover table-bordered table-sm"><tbody>';
    tableTop += `<thead class="small-header hidden-md-down">${$(
      ".list-table thead"
    ).html()}</thead>`;
    return `${tableTop}${binxAppOrgParkingNotifications.tableRowForRecord(
      record
    )}</tbody></table>`;
  }

  renderRecordsTable(records) {
    let body_html = "";
    for (const record of Array.from(records)) {
      body_html += binxAppOrgParkingNotifications.tableRowForRecord(record);
    }
    if (body_html.length < 2) {
      // If there aren't any records that were added, render a note about there not being any records
      body_html = "<tr><td colspan=7>No matching notifications</td></tr>";
    }

    // Render the body - whether it says no records or records
    $("#recordsTable tbody").html(body_html);
    // And localize the times since we added times to the table
    window.timeParser.localize();
    $("#recordsCount .number").text(records.length);
    // render the total count too
    $("#recordsTotalCount .number").text(
      binxAppOrgParkingNotifications.records.length
    );
  }

  addMarkerPointsForRecords(records) {
    binxMapping.markerPointsToRender = records.map(function(record) {
      return {
        id: record.id,
        lat: record.lat,
        lng: record.lng
      };
    });
    return binxMapping.markerPointsToRender;
  }

  updateRecords(records) {
    binxMapping.removeMarkersWithoutMatchingIds(records);
    this.addMarkerPointsForRecords(records);
    // Then render the points - fitMap false, or else it will retrigger rerendering list from the movement
    binxMapping.addMarkers({ fitMap: false });
    // TODO: don't just remove and rerender everything
    this.renderRecordsTable(this.visibleRecords(records));
  }

  renderOrganizedRecords(records) {
    // Store the records on the window class so we have them
    this.records = records;

    // Don't rerender the list if it's already rendered
    if (this.listRendered) {
      return this.updateRecords(records);
    }

    // Render the table of records
    this.renderRecordsTable(records);
    // Set the updated statuses based on what we rendered
    this.listRendered = true;
    // call map organized records - so that we can render it
    this.mapOrganizedRecords();
  }
}
