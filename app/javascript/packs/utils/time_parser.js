import log from "../utils/log";
import moment from "moment-timezone";

const TimeParser = () => {
  return {
    displayLocalDate(time, preciseTime) {
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
    },

    preciseTimeSeconds(time) {
      return time.format("YYYY-MM-DD h:mm:ss a");
    },

    localize() {
      if (!window.localTimezone) {
        window.localTimezone = moment.tz.guess();
      }
      moment.tz.setDefault(window.localTimezone);
      window.yesterday = moment()
        .subtract(1, "day")
        .startOf("day");
      window.today = moment().startOf("day");
      window.tomorrow = moment().endOf("day");

      let displayLocalDate = this.displayLocalDate;
      let preciseTimeSeconds = this.preciseTimeSeconds;
      // Update any hidden fields with current timezone
      $(".hiddenFieldTimezone").val(window.localTimezone);

      // Write local time
      $(".convertTime").each(function() {
        let $this = $(this);
        let text = $this.text().trim();
        let time = null;
        $this.removeClass("convertTime");
        $this.addClass("convertedTime"); // So we can style it
        if (!(text.length > 0)) {
          return;
        }
        // If time is only a number, parse as a timestamp
        // Otherwise, parse as ISO_8601 which is what convert_time strftimes into
        if (/^\d+$/.test(text)) {
          time = moment.unix(text);
        } else {
          time = moment(text, moment.ISO_8601);
        }
        if (!time.isValid()) {
          return;
        }
        $this
          .text(displayLocalDate(time, $this.hasClass("preciseTime")))
          .attr("title", preciseTimeSeconds(time));
      });

      // Write timezone
      $(".convertTimezone").each(function() {
        let $this = $(this);
        $this.text(moment().format("z"));
        return $this.removeClass("convertTimezone");
      });
    }
  };
};

export default TimeParser;
