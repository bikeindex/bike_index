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
      if (!window.timezone) {
        window.timezone = moment.tz.guess();
      }
      moment.tz.setDefault(window.timezone);
      window.yesterday = moment()
        .subtract(1, "day")
        .startOf("day");
      window.today = moment().startOf("day");
      window.tomorrow = moment().endOf("day");

      let displayLocalDate = this.displayLocalDate;
      let preciseTimeSeconds = this.preciseTimeSeconds;
      // Write local time
      $(".convertTime").each(function() {
        let $this = $(this);
        $this.removeClass("convertTime");
        $this.addClass("convertedTime"); // So we can style it
        let text = $this.text().trim();
        if (!(text.length > 0)) {
          return;
        }
        let time = moment(text, moment.ISO_8601);
        log.debug(time, time.format("YYYY-MM-DD h:mma"));
        if (!time.isValid) {
          log.debug("ffffff");
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
