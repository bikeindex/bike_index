// This is stuff that needs to happen on page load.
import * as log from "loglevel";
if (process.env.NODE_ENV != "production") log.setLevel("debug");
import moment from "moment-timezone";

window.binxApp || (window.binxApp = {});

binxApp.displayLocalDate = function(time, preciseTime) {
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

binxApp.preciseTimeSeconds = function(time) {
  return time.format("YYYY-MM-DD h:mm:ssa");
};

binxApp.localizeTimes = function() {
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
    $this
      .text(binxApp.displayLocalDate(time, $this.hasClass("preciseTime")))
      .attr("title", binxApp.preciseTimeSeconds(time));
  });

  // Write timezone
  return $(".convertTimezone").each(function() {
    const $this = $(this);
    $this.text(moment().format("z"));
    return $this.removeClass("convertTimezone");
  });
};

binxApp.enableFilenameForUploads = function() {
  $("input.custom-file-input[type=file]").on("change", function(e) {
    // The issue is that the files list isn't actually an array. So we can't map it
    let files = [];
    let i = 0;
    while (i < e.target.files.length) {
      files.push(e.target.files[i].name);
      i++;
    }
    $(this)
      .parent()
      .find(".custom-file-label")
      .text(files.join(", "));
  });
};

import "./binx_mapping.js";
import "./binx_org_messages.js";
import "./binx_admin.js";
import "./binx_org_export.js";

// I've made the choice to have classes' first letter capitalized
// and make the instance of class (which I'm storing on window) the same name without the first letter capitalized
// I'm absolutely sure there is a best practice that I'm ignoring, but just doing it for now.
$(document).ready(function() {
  binxApp.localizeTimes();
  // Load admin, whatever
  if ($("#admin-content").length > 0) {
    window.binxAdmin = new BinxAdmin();
    binxAdmin.init();
  }
  // Load the page specific things
  let body_id = document.getElementsByTagName("body")[0].id;
  switch (body_id) {
    case "organized_messages_index":
      window.binxMapping = new BinxMapping("geolocated_messages");
      window.binxAppOrgMessages = new BinxAppOrgMessages();
      binxAppOrgMessages.init();
    case "organized_exports_show":
    case "organized_exports_new":
      window.binxAppOrgExport = new BinxAppOrgExport();
      binxAppOrgExport.init();
  }
});
