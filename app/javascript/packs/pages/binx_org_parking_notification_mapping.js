import log from "../utils/log";
import _ from "lodash";

export default class BinxAppOrgParkingNotificationMapping {
  constructor() {
    this.fetchedRecords = false;
    this.mapReady = false;
    this.listRendered = false;
    this.defaultLocation;
    this.records = [];
    this.totalRecords = 0;
    this.perPage = 0;
    this.page = 0;
  }

  init() {
    // load the maps API
    binxMapping.loadMap(
      "binxAppOrgParkingNotificationMapping.mapOrganizedRecords"
    );
    this.fetchRecords();

    // On period update, fetch records
    const fetchRecords = this.fetchRecords;
    $("#timeSelectionCustom").on("submit", (e) => {
      fetchRecords();
      return false;
    });
    $("#timeSelectionBtnGroup .btn").on("click", (e) => {
      fetchRecords();
      return true; // Returns true because of bootstrap button list actions
    });
    $("#redo-search-in-map").on("click", (e) => {
      binxAppOrgParkingNotificationMapping.fetchRecordsWithCurrentLocation();
      return false;
    });
    $("#FitMapTrigger").on("click", (e) => {
      e.preventDefault();
      // If there are no notifications in the window, and we have passed a location, load the page without a location
      if (binxAppOrgParkingNotificationMapping.zeroVisibleAtLocation()) {
        window.location = binxAppOrgParkingNotificationMapping.urlForOpts([
          ["search_southwest_coords", ""],
          ["search_northeast_coords", ""],
        ]);
      } else {
        binxMapping.fitMap();
      }
      return false; // prevent default action
    });

    $("#recordsTable, #parking-notification-nav-links").on(
      "click",
      ".linkWithSortableSearchParams",
      (e) => {
        const $target = $(e.target);
        if ($target.attr("data-urlparams")) {
          e.preventDefault();
          let urlOpts = $target.attr("data-urlparams").split(",");
          let urlParams = binxAppOrgParkingNotificationMapping.urlParamsForOpts(
            [urlOpts]
          );
          window.location = `${location.pathname}?${urlParams.toString()}`;
        }
      }
    );
  }

  urlForOpts(opts = []) {
    return `${
      location.pathname
    }?${binxAppOrgParkingNotificationMapping
      .urlParamsForOpts(opts)
      .toString()}`;
  }

  fetchRecordsWithCurrentLocation(opts = []) {
    // Add the current location, unless we're fetching the default location - or a location was passed in
    if (!window.pageInfo.default_location) {
      // check for the boundary box keys
      const optsValues = opts.map((param) => param[0]);
      if (!optsValues.includes("search_southwest_coords")) {
        opts = opts.concat(binxMapping.boundingBoxParams());
      }
    }
    return binxAppOrgParkingNotificationMapping.fetchRecords(opts);
  }

  urlParamsForOpts(opts = []) {
    // Use the period selector urlParams - which will use the current period -
    // even if the period is default (and not in the url)
    let urlParams = window.periodSelector.urlParamsWithNewPeriod();

    for (const param of opts) {
      urlParams.delete(param[0]); // remove any matching parameters
      if (param[1] !== null && param[1].length) {
        urlParams.append(param[0], param[1]);
      }
    }
    return urlParams;
  }

  fetchRecords(opts = []) {
    $("#redo-search-in-map").fadeOut();

    const urlParams = binxAppOrgParkingNotificationMapping.urlParamsForOpts(
      opts
    );
    const url = binxAppOrgParkingNotificationMapping.urlForOpts(opts);

    // Update the address bar to include the current parameters
    history.replaceState({}, "", url);

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
        binxAppOrgParkingNotificationMapping.fetchedRecords = true;
        binxAppOrgParkingNotificationMapping.setPaginationInfo(jqXHR);
        binxAppOrgParkingNotificationMapping.renderOrganizedRecords(
          data.parking_notifications
        );
      },
      error(data, textStatus, jqXHR) {
        binxAppOrgParkingNotificationMapping.fetchedRecords = true;
        log.debug(data);
      },
    });
  }

  setPaginationInfo(jqXHR) {
    this.totalRecords = parseInt(jqXHR.getResponseHeader("Total"), 10);
    this.perPage = parseInt(jqXHR.getResponseHeader("Per-Page"), 10);
    this.page = parseInt(jqXHR.getResponseHeader("Page"), 10);
  }

  // Grabs the visible markers, looks up the records from them and returns that list
  visibleRecords() {
    return binxMapping.markersInViewport().map((marker) => {
      return this.records.find((record) => marker.binxId == record.id);
    });
  }

  zeroVisibleAtLocation() {
    // If there is a stored location and there are no records there at all
    return (
      binxAppOrgParkingNotificationMapping.records.length === 0 &&
      binxAppOrgParkingNotificationMapping
        .urlParamsForOpts()
        .getAll("search_southwest_coords").length
    );
  }

  // this loops and calls itself again if we haven't finished rendering the map and the records
  mapOrganizedRecords() {
    // if we have already rendered the mapRendered, then we're done!
    if (binxMapping.mapRendered) {
      return true;
    }
    if (binxMapping.googleMapsLoaded()) {
      if (!binxAppOrgParkingNotificationMapping.mapReady) {
        binxMapping.render(
          window.pageInfo.map_center_lat,
          window.pageInfo.map_center_lng
        );
        binxAppOrgParkingNotificationMapping.mapReady = true;
      }
      // If the record list is rendered, it means we could be finished rendering!
      // Otherwise we haven't finished rendering and we need to loop this method
      if (binxAppOrgParkingNotificationMapping.listRendered) {
        // The records are loaded, so process the records into markers
        binxAppOrgParkingNotificationMapping.addMarkerPointsForRecords(
          binxAppOrgParkingNotificationMapping.records
        );
        // Then render the points
        return binxAppOrgParkingNotificationMapping.inititalizeMapMarkers();
      }
    }
    // call this again in .5 seconds, unless we returned prematurely (because things have rendered)
    log.debug("looping mapOrganizedRecords");
    setTimeout(binxAppOrgParkingNotificationMapping.mapOrganizedRecords, 500);
  }

  // When the link button is clicked on the table, scroll up to the map and open the applicable marker
  addTableMapLinkHandler() {
    $("#recordsTable").on("click", ".map-cell a", (e) => {
      e.preventDefault();
      let recordId = parseInt(
        $(e.target).parents("tr").attr("data-recordid"),
        10
      );
      if (isNaN(recordId)) {
        return window.BikeIndexAlerts.add(
          "error",
          "Unable to find that record!"
        );
      }
      let record = _.find(
        binxAppOrgParkingNotificationMapping.records,
        function (record) {
          return recordId == record.id;
        }
      );
      let marker = _.find(binxMapping.markersRendered, function (marker) {
        return recordId == marker.binxId;
      });
      binxMapping.openInfoWindow(marker, recordId, record);
      $("body, html").animate(
        {
          scrollTop: $(".organized-records #map").offset().top - 60, // 60px offset
        },
        "fast"
      );
    });
  }

  inititalizeMapMarkers() {
    binxMapping.addMarkers({
      fitMap: window.pageInfo.default_location, // only fitMap if it's the default location
    });

    // Add a trigger to the map when the viewport changes (after it has finished moving)
    google.maps.event.addListener(binxMap, "idle", function () {
      // This is grabbing the markers in viewport and logging the ids for them.
      // We actually need to rerender the the marker table
      log.debug("rerendering table because map");
      binxAppOrgParkingNotificationMapping.renderRecordsTable(
        binxAppOrgParkingNotificationMapping.visibleRecords()
      );
      if (binxMapping.mapRendered) {
        $("#redo-search-in-map").fadeIn();
        window.pageInfo.default_location = false;
      }
    });
    this.addTableMapLinkHandler();
  }

  mapPopup(point) {
    let record = _.find(binxAppOrgParkingNotificationMapping.records, [
      "id",
      point.id,
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
      body_html = "<tr><td colspan=8>No matching notifications</td></tr>";
    }

    // Render the body - whether it says no records or records
    $("#recordsTable tbody").html(body_html);

    binxAppOrgParkingNotificationMapping.updateTotalCount(records.length);
    // And localize the times since we added times to the table
    window.timeParser.localize();
  }

  updateTotalCount(renderedCount) {
    $(".recordsCount .number").text(renderedCount);
    // render the total count too
    $(".recordsTotalCount .number").text(
      binxAppOrgParkingNotificationMapping.totalRecords
    );
    // If there are more total records, show the maxNumber columns
    if (
      binxAppOrgParkingNotificationMapping.totalRecords >=
      binxAppOrgParkingNotificationMapping.perPage
    ) {
      $(".maxNumberDisplayed").slideDown();
    } else {
      $(".maxNumberDisplayed").slideUp();
    }
    // If there is a missmatch between the records found and the records visible, show fitToMap
    if (
      renderedCount !== binxAppOrgParkingNotificationMapping.records.length ||
      binxAppOrgParkingNotificationMapping.zeroVisibleAtLocation()
    ) {
      $("#FitMapTrigger").slideDown();
    } else {
      $("#FitMapTrigger").slideUp();
    }
  }

  addMarkerPointsForRecords(records) {
    binxMapping.markerPointsToRender = records.map(function (record) {
      return {
        id: record.id,
        lat: record.lat,
        lng: record.lng,
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
