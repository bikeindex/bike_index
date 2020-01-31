import log from "../utils/log";
import _ from "lodash";

export default class BinxAppOrgAbandonedRecords {
  constructor() {
    this.fetchedRecords = false;
    this.mapReady = false;
    this.listRendered = false;
    this.mapRendered = false;
    this.records = [];
  }

  init() {
    log.debug("loading abandoned records");
    // load the maps API
    binxMapping.loadMap("binxAppOrgAbandonedRecords.mapOrganizedRecords");
    this.fetchRecords([["per_page", 50]]);
  }

  fetchRecords(opts) {
    let urlParams = new URLSearchParams(window.location.search);
    for (const param of opts) {
      urlParams.append(param[0], param[1]);
    }
    // lazy parameter to query string
    let queryString = opts.map(i => `${i[0]}=${i[1]}`);
    let url = `${window.pageInfo.root_path}?${urlParams.toString()}`;
    // Using ajax here instead of fetch because we're relying on the cookies for auth for now
    $.ajax({
      type: "GET",
      dataType: "json",
      url: url,
      success(data, textStatus, jqXHR) {
        binxAppOrgAbandonedRecords.fetchedRecords = true;
        binxAppOrgAbandonedRecords.renderOrganizedRecords(
          data.abandoned_records
        );
      },
      error(data, textStatus, jqXHR) {
        binxAppOrgAbandonedRecords.fetchedRecords = true;
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
    if (binxAppOrgAbandonedRecords.mapRendered) {
      return true;
    }
    if (binxMapping.googleMapsLoaded()) {
      if (!binxAppOrgAbandonedRecords.mapReady) {
        binxMapping.render(
          window.pageInfo.map_center_lat,
          window.pageInfo.map_center_lng
        );
        binxAppOrgAbandonedRecords.mapReady = true;
      }
      // If the record list is rendered, it means we could be finished rendering!
      // Otherwise we haven't finished rendering and we need to loop this method
      if (binxAppOrgAbandonedRecords.listRendered) {
        // The records are loaded, so process the records into markers
        binxAppOrgAbandonedRecords.addMarkerPointsForRecords(
          binxAppOrgAbandonedRecords.records
        );
        // Then render the points
        return binxAppOrgAbandonedRecords.inititalizeMapMarkers();
      }
    }
    // call this again in .5 seconds, unless we returned prematurely (because things have rendered)
    log.debug("looping mapOrganizedRecords");
    setTimeout(binxAppOrgAbandonedRecords.mapOrganizedRecords, 500);
  }

  // When the link button is clicked on the table, scroll up to the map and open the applicable marker
  addTableMapLinkHandler() {
    $("#records_table").on("click", ".map-cell a", e => {
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
      let record = _.find(binxAppOrgAbandonedRecords.records, function(record) {
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
      binxAppOrgAbandonedRecords.renderRecordsTable(
        binxAppOrgAbandonedRecords.visibleRecords()
      );
    });
    this.addTableMapLinkHandler();
  }

  tableRowForRecord(record) {
    const showCellUrl = `${window.pageInfo.root_path}/${record.id}`;
    let user = window.pageInfo.members[record.user_id];
    if (user !== undefined) {
      user = user.name;
    } else {
      user = "?";
    }
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
    }</em> - by ${user}</span> <span class="extended-col-info"><br>${bikeLink}</span>
      </td><td class="hidden-sm-cells">${bikeLink}</td><td class="hidden-sm-cells"><em>${
      record.kind_humanized
    }</em></td><td class="hidden-sm-cells">${user}</td><td class="hidden-sm-cells">${impoundLink}</td>`;
  }

  abandonedRecordMapPopup(point) {
    let record = _.find(binxAppOrgAbandonedRecords.records, ["id", point.id]);
    let tableTop =
      '<table class="table table table-striped table-hover table-bordered table-sm"><tbody>';
    tableTop += `<thead class="small-header hidden-md-down">${$(
      ".list-table thead"
    ).html()}</thead>`;
    return `${tableTop}${binxAppOrgAbandonedRecords.tableRowForRecord(
      record
    )}</tbody></table>`;
  }

  renderRecordsTable(records) {
    let body_html = "";
    for (const record of Array.from(records)) {
      body_html += binxAppOrgAbandonedRecords.tableRowForRecord(record);
    }
    if (body_html.length < 2) {
      // If there aren't any records that were added, render a note about there not being any records
      body_html =
        "<tr><td colspan=6>No matching records have been sent</td></tr>";
    }

    // Render the body - whether it says no records or records
    $("#records_table tbody").html(body_html);
    // And localize the times since we added times to the table
    window.timeParser.localize();

    $("#recordsCount .number").text(records.length);
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

  renderOrganizedRecords(records) {
    // Don't rerender the list if it's already rendered
    if (this.listRendered) {
      return true;
    }
    // Store the records on the window class so we have them
    this.records = records;
    // Render the table of records
    this.renderRecordsTable(records);
    // Set the updated statuses based on what we rendered
    this.listRendered = true;
    // call map organized records - so that we can render it
    this.mapOrganizedRecords();
  }
}
