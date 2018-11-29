// This is stuff that needs to happen on page load.
// Eventually, things will get more complicated and be split up - but for now, just one lame file

import moment from "moment-timezone";
import * as log from "loglevel";

const displayLocalDate = function(time, preciseTime) {
  // Ensure we return if it's a big future day
  if (preciseTime == null) {
    preciseTime = false;
  }
  if (time < window.tomorrow) {
    if (time > window.today) {
      return time.format("h:mma");
    } else if (time > window.yesterday) {
      return `Yesterday ${time.format("h:mma")}`;
    }
  }
  if (time.year() === moment().year()) {
    if (preciseTime) {
      return time.format("MMM Do[,] h:mma");
    } else {
      return time.format("MMM Do[,] ha");
    }
  } else {
    if (preciseTime) {
      return time.format("YYYY-MM-DD h:mma");
    } else {
      return time.format("YYYY-MM-DD");
    }
  }
};

const localizeTimes = function() {
  if (!window.timezone) {
    window.timezone = moment.tz.guess();
  }
  moment.tz.setDefault(window.timezone);
  window.yesterday = moment()
    .subtract(1, "day")
    .startOf("day");
  window.today = moment().startOf("day");
  window.tomorrow = moment().endOf("day");

  // Write local time
  $(".convertTime").each(function() {
    const $this = $(this);
    $this.removeClass("convertTime");
    const text = $this.text().trim();
    if (!(text.length > 0)) {
      return;
    }
    let time = "";
    if (isNaN(text)) {
      time = moment(text, moment.ISO_8601);
    } else {
      // it's a timestamp!
      time = moment.unix(text);
    }

    if (!time.isValid) {
      return;
    }
    return $this.text(displayLocalDate(time, $this.hasClass("preciseTime")));
  });

  // Write timezone
  return $(".convertTimezone").each(function() {
    const $this = $(this);
    $this.text(moment().format("z"));
    return $this.removeClass("convertTimezone");
  });
};

const initializeGoogleMap = function(callback) {
  if (window.googleMapInjected || googleMapsLoaded()) {
    return true;
  }
  // Add google maps script
  var js_file = document.createElement("script");
  js_file.type = "text/javascript";
  js_file.src = `https://maps.googleapis.com/maps/api/js?callback=${callback}&key=${
    window.pageInfo.google_maps_key
  }&`;
  document.getElementsByTagName("head")[0].appendChild(js_file);
  window.googleMapInjected = true;
};

const googleMapsLoaded = function() {
  return typeof google === "object" && typeof google.maps === "object";
};

// Window function because we're calling it from google maps callback
// it calls itself if we haven't loaded google maps and if we haven't
window.mapOrganizedMessages = function() {
  if (googleMapsLoaded()) {
    log.warn("maps LOADED");
    if (!window.messagePageStatus.mapReady) {
      // render the actual map,
      window.messagePageStatus.mapReady = true;
    }
    // If the message list is rendered, it means we could be finished rendering!
    // Otherwise we haven't finished rendering and we need to loop this method
    if (window.messagePageStatus.messagesListRendered) {
      // if we have already rendered the messagesMapRendered, then we're done!
      if (window.messagePageStatus.messagesMapRendered) {
        return true;
      }
      // Otherwise we rendered the list without rendering the map points, so just render
      if (messages.length > 0) {
        for (let message of Array.from(window.messagePageStatus.messages)) {
          log.warn(message);
        }
      }
      messagePageStatus.messagesMapRendered = true;
    }
  }
  // call this again in .5 seconds, unless we returned prematurely from here
  log.warn("looping the mapOrganizedMessages method");
  setTimeout(mapOrganizedMessages, 500);
};

const renderOrganizedMessages = function(messages) {
  window.messagePageStatus.messages = messages;
  let body_html = "";
  // Don't rerender the list if it's already rendered
  if (window.messagePageStatus.messagesListRendered) {
    return true;
  }
  // Render the messages table, simultaneously render the google pins - only if google maps is loaded
  // Set here, since if it becomes available part way through the rendering we don't want to only render part of the messages
  let simultaneousMapRender = window.messagePageStatus.mapReady;
  log.warn(`simultaneousMapRender:  ${simultaneousMapRender}`);
  if (messages.length > 0) {
    for (let message of Array.from(messages)) {
      let bikeCellUrl = `/bikes/${message.bike.id}`;
      let sentCellUrl = `${window.pageInfo.message_root_path}/${message.id}`;
      let sender = window.pageInfo.members[message.sender_id];
      if (sender !== undefined) {
        sender = sender.name;
      }
      body_html += `<tr><td><a href="${sentCellUrl}" class="convertTime">${
        message.created_at
      }</a></td><td><a href="${bikeCellUrl}">${
        message.bike.title
      }</a></td><td>${sender}</td>`;
    }
  } else {
    body_html += "<tr><td colspan=4>No messages have been sent</td></tr>";
  }
  // Render the body - whether it says no messages or messages
  $("#messages_table tbody").html(body_html);
  // Set the updated statuses based on what we rendered
  window.messagePageStatus.messagesListRendered = true;
  window.messagePageStatus.messagesMapRendered = simultaneousMapRender;
  // If we didn't simultaneously render, call map organized messages - because we need to render them
  if (!simultaneousMapRender) {
    mapOrganizedMessages();
  }
  log.warn(
    "just checking that we hit this always despite calling method above here XXXXXXX"
  );
  localizeTimes();
};

const initializeOrganizedMessages = function() {
  window.messagePageStatus = {
    fetchedMessages: false,
    mapReady: false,
    messagesListRendered: false,
    messagesMapRendered: false,
    messages: []
  };
  // load the google maps API
  initializeGoogleMap("mapOrganizedMessages");
  // Fetch the messages. Using ajax here instead of fetch because we're relying on the cookies for auth for now
  $.ajax({
    type: "GET",
    dataType: "json",
    url: window.pageInfo.message_root_path,
    success(data, textStatus, jqXHR) {
      window.messagePageStatus.fetchedMessages = true;
      renderOrganizedMessages(data.messages);
    },
    error(data, textStatus, jqXHR) {
      window.messagePageStatus.fetchedMessages = true;
      log.warn(data);
    }
  });
};

$(document).ready(function() {
  // We don't need to localizeTimes here, because we're already doing it in the existing init script

  // Load the page specific things
  let body_id = document.getElementsByTagName("body")[0].id;
  switch (body_id) {
    case "organized_messages_index":
      initializeOrganizedMessages();
  }
});
