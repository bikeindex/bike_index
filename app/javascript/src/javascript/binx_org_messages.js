import * as log from "loglevel";
if (process.env.NODE_ENV != "production") log.setLevel("debug");

window.BinxAppOrgMessages = class BinxAppOrgMessages {
  constructor() {
    this.fetchedMessages = false;
    this.mapReady = false;
    this.messagesListRendered = false;
    this.messagesMapRendered = false;
    this.messages = [];
  }

  init() {
    // load the maps API
    binxMapping.loadMap("binxAppOrgMessages.mapOrganizedMessages");
    binxAppOrgMessages.fetchMessages([["per_page", 50]]);
  }

  fetchMessages(opts) {
    // lazy parameter to query string
    let queryString = opts.map(i => `${i[0]}=${i[1]}`);
    let url = `${window.pageInfo.message_root_path}?${queryString.join("&")}`;
    // Using ajax here instead of fetch because we're relying on the cookies for auth for now
    $.ajax({
      type: "GET",
      dataType: "json",
      url: url,
      success(data, textStatus, jqXHR) {
        binxAppOrgMessages.fetchedMessages = true;
        binxAppOrgMessages.renderOrganizedMessages(data.messages);
      },
      error(data, textStatus, jqXHR) {
        binxAppOrgMessages.fetchedMessages = true;
        log.debug(data);
      }
    });
  }

  // Grabs the visible markers, looks up the messages from them and returns that list
  visibleMessages() {
    return _.map(binxMapping.markersInViewport(), function(marker) {
      return _.find(binxAppOrgMessages.messages, function(message) {
        return marker.binxId == message.id;
      });
    });
  }

  // this loops and calls itself again if we haven't finished rendering the map and the messages
  mapOrganizedMessages() {
    // if we have already rendered the messagesMapRendered, then we're done!
    if (binxAppOrgMessages.messagesMapRendered) {
      return true;
    }
    if (binxMapping.googleMapsLoaded()) {
      if (!binxAppOrgMessages.mapReady) {
        binxMapping.render(
          window.pageInfo.map_center_lat,
          window.pageInfo.map_center_lng
        );
        binxAppOrgMessages.mapReady = true;
      }
      // If the message list is rendered, it means we could be finished rendering!
      // Otherwise we haven't finished rendering and we need to loop this method
      if (binxAppOrgMessages.messagesListRendered) {
        // The messages are loaded, so process the messages into markers
        binxAppOrgMessages.addMarkerPointsForMessages(
          binxAppOrgMessages.messages
        );
        // Then render the points
        return binxAppOrgMessages.inititalizeMapMarkers();
      }
    }
    // call this again in .5 seconds, unless we returned prematurely (because things have rendered)
    log.debug("looping mapOrganizedMessages");
    setTimeout(binxAppOrgMessages.mapOrganizedMessages, 500);
  }

  // When the link button is clicked on the table, scroll up to the map and open applicable marker
  addTableMapLinkHandler() {
    $("#messages_table").on("click", ".map-cell a", e => {
      e.preventDefault();
      let messageId = parseInt(
        $(e.target)
          .parents("tr")
          .attr("data-msgid"),
        10
      );
      if (isNaN(messageId)) {
        return window.BikeIndexAlerts.add(
          "error",
          "Unable to find that message!"
        );
      }
      let message = _.find(binxAppOrgMessages.messages, function(message) {
        return messageId == message.id;
      });
      let marker = _.find(binxMapping.markersRendered, function(marker) {
        return messageId == marker.binxId;
      });
      binxMapping.openInfoWindow(marker, messageId, message);
      $("body, html").animate(
        {
          scrollTop: $(".organized-messages #map").offset().top - 60 // 60px offset
        },
        "fast"
      );
    });
  }

  inititalizeMapMarkers() {
    binxMapping.addMarkers({ fitMap: true });
    binxAppOrgMessages.messagesMapRendered = true;
    // Add a trigger to the map when it becomes idle after panning or zooming.
    google.maps.event.addListener(binxMap, "idle", function() {
      // This is grabbing the markers in viewport and logging the ids for them.
      // We actually need to rerender the the marker table
      binxAppOrgMessages.renderMessagesTable(
        binxAppOrgMessages.visibleMessages()
      );
    });
    binxAppOrgMessages.addTableMapLinkHandler();
  }

  tableRowForMessage(message) {
    let bikeCellUrl = `/bikes/${message.bike.id}`;
    let sentCellUrl = `${window.pageInfo.message_root_path}/${message.id}`;
    let sender = window.pageInfo.members[message.sender_id];
    if (sender !== undefined) {
      sender = sender.name;
    }
    return `<tr class="message-row" data-msgid="${
      message.id
    }"><td class="map-cell"><a>↑</a></td><td><a href="${sentCellUrl}" class="convertTime">${
      message.created_at
    }</a></td><td><a href="${bikeCellUrl}">${
      message.bike.title
    }</a></td><td>${sender}</td>`;
  }

  geolocatedMessageMapPopup(point) {
    let message = _.find(binxAppOrgMessages.messages, ["id", point.id]);
    let tableTop =
      '<table class="table table table-striped table-hover table-bordered table-sm"><tbody>';
    tableTop +=
      '<tr><td class="map-cell"></td><td>Sent</td><td>Bike</td><td>Sender</td></tr>';
    return `${tableTop}${binxAppOrgMessages.tableRowForMessage(
      message
    )}</tbody></table>`;
  }

  renderMessagesTable(messages) {
    let body_html = "";

    for (let message of Array.from(messages)) {
      body_html += binxAppOrgMessages.tableRowForMessage(message);
    }
    if (body_html.length < 2) {
      // If there aren't any messages that were added, render a note about there not being any messages
      body_html =
        "<tr><td colspan=4>No matching messages have been sent</td></tr>";
    }

    // Render the body - whether it says no messages or messages
    $("#messages_table tbody").html(body_html);

    $("#messagesCount .number").text(messages.length);
    if (messages.length == 1) {
      $("#messagesCount").removeClass("number-is-plural");
    } else {
      $("#messagesCount").addClass("number-is-plural");
    }
  }

  addMarkerPointsForMessages(messages) {
    binxMapping.markerPointsToRender = messages.map(function(message) {
      return {
        id: message.id,
        lat: message.lat,
        lng: message.lng
      };
    });
    return binxMapping.markerPointsToRender;
  }

  renderOrganizedMessages(messages) {
    // Don't rerender the list if it's already rendered
    if (binxAppOrgMessages.messagesListRendered) {
      return true;
    }
    // Store the messages on the window class so we have them
    binxAppOrgMessages.messages = messages;
    // Render the table of messages
    binxAppOrgMessages.renderMessagesTable(messages);
    // Set the updated statuses based on what we rendered
    binxAppOrgMessages.messagesListRendered = true;
    // call map organized messages - so that we can render it
    binxAppOrgMessages.mapOrganizedMessages();
    // And localize the times since we added times to the table
    binxApp.localizeTimes();
  }
};
