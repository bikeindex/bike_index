// This is stuff that needs to happen on page load.
// Eventually, things will get more complicated and be split up - but for now, just one lame file

import moment from "moment-timezone";

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

const renderOrganizedMessages = function(messages) {
  let body_html = "";
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
  $("#messages_table tbody").html(body_html);
  localizeTimes();
};

const initializeOrganizedMessages = function() {
  // Using ajax here instead of fetch because we're relying on the cookies for now
  $.ajax({
    type: "GET",
    dataType: "json",
    url: window.pageInfo.message_root_path,
    success(data, textStatus, jqXHR) {
      renderOrganizedMessages(data.messages);
    },
    error(data, textStatus, jqXHR) {
      console.log(data);
    }
  });
};

$(document).ready(function() {
  // We don't need to localizeTimes, because we're already doing it in the existing init script
  // localizeTimes();
  // Load the page specific things
  let body_id = document.getElementsByTagName("body")[0].id;
  switch (body_id) {
    case "organized_messages_index":
      initializeOrganizedMessages();
  }
});
