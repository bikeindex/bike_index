import log from "../utils/log";
import moment from "moment-timezone";

// Should be imported and initialized like this:
// if (!window.timeParser) { window.timeParser = new TimeParser() }

// And then you can add this to the react component:
// componentDidUpdate() { window.timeParser.localize() }

export default class TimeParser {
  constructor() {
    if (!window.localTimezone) {
      window.localTimezone = moment.tz.guess();
    }
    this.localTimezone = window.localTimezone;
    moment.tz.setDefault(this.localTimezone);
    this.yesterday = moment()
      .subtract(1, "day")
      .startOf("day");
    this.today = moment().startOf("day");
    this.tomorrow = moment().endOf("day");
  }

  localizedDateText(time, classList) {
    // Ensure we return something if it's today or a future day
    if (time < this.tomorrow) {
      if (time > this.today) {
        if (classList.contains("preciseTimeSeconds")) {
          return `${time.format("h:mm:")}<small>${time.format(
            "ss"
          )}</small> ${time.format("a")}`;
        } else {
          return time.format("h:mma");
        }
      }
    }
    // Return yesterday specific things
    if (time > this.yesterday) {
      if (classList.contains("preciseTimeSeconds")) {
        return `Yesterday ${time.format("h:mm:")}<small>${time.format(
          "ss"
        )}</small> ${time.format("a")}`;
      } else {
        return `Yesterday ${time.format("h:mma")}`;
      }
    }
    // If it's preciseTimeSeconds, format with seconds
    if (classList.contains("preciseTimeSeconds")) {
      if (time.year() === moment().year()) {
        return `${time.format("MMM Do[,] h:mm:")}<small>${time.format(
          "ss"
        )}</small> ${time.format("a")}`;
      } else {
        return `${time.format("YYYY-MM-DD h:mma")}<small>${time.format(
          "ss"
        )}</small> ${time.format("a")}`;
      }
    }
    // If it's preciseTime, always show hours and mins
    if (classList.contains("preciseTime")) {
      if (time.year() === moment().year()) {
        return time.format("MMM Do[,] h:mma");
      } else {
        return time.format("YYYY-MM-DD h:mma");
      }
    }
    // Otherwise, format in basic format
    if (time.year() === moment().year()) {
      return time.format("MMM Do[,] ha");
    } else {
      return time.format("YYYY-MM-DD");
    }
  }

  preciseTimeSeconds(time) {
    return time.format("YYYY-MM-DD h:mm:ss a");
  }

  setHiddenTimezoneFields(el) {
    el.value = this.localTimezone;
  }

  writeUpdatedTimeText(el) {
    let text = el.textContent.trim();
    let time = null;
    // So running this again doesn't reapply to this element
    el.classList.remove("convertTime");
    // So we know which were updated (for styling, future updates, etc)
    el.classList.add("convertedTime");

    if (!(text.length > 0)) {
      return;
    }
    // If time is only a number, parse as a timestamp
    // Otherwise, parse as ISO_8601 which is the default time string
    if (/^\d+$/.test(text)) {
      time = moment.unix(text);
    } else {
      time = moment(text, moment.ISO_8601);
    }
    if (time === null || !time.isValid()) {
      return;
    }

    el.innerHTML = this.localizedDateText(time, el.classList);
    el.setAttribute("title", this.preciseTimeSeconds(time));
  }

  writeTimezone(el) {
    el.textContent = moment().format("z");
    el.classList.remove("convertTimezone");
  }

  localize() {
    // Write times
    Array.from(document.getElementsByClassName("convertTime")).forEach(el =>
      this.writeUpdatedTimeText(el)
    );

    // Write timezones
    Array.from(document.getElementsByClassName("convertTimezone")).forEach(el =>
      this.writeTimezone(el)
    );

    // Write hidden timezone fields - so if we're submitting a form, it includes the current timezone
    Array.from(document.getElementsByClassName("hiddenFieldTimezone")).forEach(
      el => this.setHiddenTimezoneFields(el)
    );
  }
}
