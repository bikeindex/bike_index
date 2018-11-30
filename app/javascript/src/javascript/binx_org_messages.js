import * as log from "loglevel";

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
        log.warn(data);
      }
    });
  }

  // this loops and calls itself again if we haven't finished rendering the map and the messages
  mapOrganizedMessages() {
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
        // if we have already rendered the messagesMapRendered, then we're done!
        if (binxAppOrgMessages.messagesMapRendered) {
          return true;
        }
        // Otherwise we rendered the list without rendering the map points, so just render
        binxMapping.addMarkers(true);
        binxAppOrgMessages.messagesMapRendered = true;
        return true;
      }
    }
    // call this again in .5 seconds, unless we returned prematurely (because things have rendered)
    log.warn("looping mapOrganizedMessages");
    setTimeout(binxAppOrgMessages.mapOrganizedMessages, 500);
  }

  tableRowForMessage(message) {
    let bikeCellUrl = `/bikes/${message.bike.id}`;
    let sentCellUrl = `${window.pageInfo.message_root_path}/${message.id}`;
    let sender = window.pageInfo.members[message.sender_id];
    if (sender !== undefined) {
      sender = sender.name;
    }
    return `<tr><td><a href="${sentCellUrl}" class="convertTime">${
      message.created_at
    }</a></td><td><a href="${bikeCellUrl}">${
      message.bike.title
    }</a></td><td>${sender}</td>`;
  }

  geolocatedMessageMapPopup(point) {
    let message = _.find(binxAppOrgMessages.messages, ["id", point.id]);
    let tableTop =
      '<table class="table table table-striped table-hover table-bordered table-sm"><tbody><tr><td>Sent</td><td>Bike</td><td>Sender</td></tr>';
    return `${tableTop}${binxAppOrgMessages.tableRowForMessage(
      message
    )}</tbody></table>`;
  }

  addMarkerPointsForMessages(messages) {
    binxMapping.markerPointsToRender = messages.map(function(message) {
      return {
        id: message.id,
        lat: message.lat,
        lng: message.lng
      };
    });
  }

  renderOrganizedMessages(messages) {
    // Don't rerender the list if it's already rendered
    if (binxAppOrgMessages.messagesListRendered) {
      return true;
    }
    binxAppOrgMessages.messages = messages;
    let body_html = "";

    for (let message of Array.from(messages)) {
      body_html += binxAppOrgMessages.tableRowForMessage(message);
    }
    if (body_html.length < 2) {
      // If there aren't any messages that were added, render a note about there not being any messages
      body_html = "<tr><td colspan=4>No messages have been sent</td></tr>";
    }

    // Render the body - whether it says no messages or messages
    $("#messages_table tbody").html(body_html);

    // Set the markers for the map, it can render as soon as messageListRendered is true
    binxAppOrgMessages.addMarkerPointsForMessages(messages);
    // Set the updated statuses based on what we rendered
    binxAppOrgMessages.messagesListRendered = true;
    // call map organized messages - so that we can render it
    binxAppOrgMessages.mapOrganizedMessages(binxAppOrgMessages.messages);
    // And localize the times since we added times to the table
    binxApp.localizeTimes();
  }
};
