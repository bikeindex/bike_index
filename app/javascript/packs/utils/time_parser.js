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
    this.yesterdayStart = moment().subtract(1, "day").startOf("day");
    this.todayStart = moment().startOf("day");
    this.todayEnd = moment().endOf("day");
    this.tomorrowEnd = moment().add(1, "day").endOf("day");
  }

  // If we're display time with the hour, we have different formats based on whether we include seconds
  // this manages that functionality
  hourFormat(time, baseTimeFormat, includeSeconds, includePreposition) {
    const prefix = includePreposition ? " at " : "";
    if (includeSeconds) {
      return `${prefix}${time.format(baseTimeFormat)}:<small>${time.format(
        "ss"
      )}</small> ${time.format("a")}`;
    } else {
      return prefix + time.format(`${baseTimeFormat}a`);
    }
  }

  localizedDateText(time, classList) {
    let prefix = "";
    // If we're dealing with yesterday or today (not the future)
    if (time < this.tomorrowEnd && time > this.yesterdayStart) {
      // If we're dealing with yesterday or tomorrow, we prepend that
      if (time < this.todayStart) {
        prefix = "Yesterday ";
      } else if (time > this.todayEnd) {
        prefix = "Tomorrow ";
      }
      return (
        prefix +
        this.hourFormat(
          time,
          "h:mm",
          classList.contains("preciseTimeSeconds"),
          classList.contains("withPreposition")
        )
      );
    }
    if (classList.contains("withPreposition")) {
      prefix = "on ";
    }

    // If it's preciseTime (or preciseTimeSeconds), always show the hours and mins
    if (
      classList.contains("preciseTime") ||
      classList.contains("preciseTimeSeconds")
    ) {
      let hourStr = this.hourFormat(
        time,
        "h:mm",
        classList.contains("preciseTimeSeconds"),
        classList.contains("withPreposition")
      );
      // Include the year if it isn't the current year
      if (time.year() === moment().year()) {
        return prefix + time.format("MMM Do[,] ") + hourStr;
      } else {
        return prefix + time.format("YYYY-MM-DD ") + hourStr;
      }
    }
    // Otherwise, format in basic format
    if (time.year() === moment().year()) {
      if (classList.contains("withPreposition")) {
        return prefix + time.format("MMM Do[,]") + " at " + time.format("ha");
      } else {
        return prefix + time.format("MMM Do[,] ha");
      }
    } else {
      return prefix + time.format("YYYY-MM-DD");
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
    Array.from(document.getElementsByClassName("convertTime")).forEach((el) =>
      this.writeUpdatedTimeText(el)
    );

    // Write timezones
    Array.from(
      document.getElementsByClassName("convertTimezone")
    ).forEach((el) => this.writeTimezone(el));

    // Write hidden timezone fields - so if we're submitting a form, it includes the current timezone
    Array.from(
      document.getElementsByClassName("hiddenFieldTimezone")
    ).forEach((el) => this.setHiddenTimezoneFields(el));
  }
}
