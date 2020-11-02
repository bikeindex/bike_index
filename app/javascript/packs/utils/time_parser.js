import log from "../utils/log";
import moment from "moment-timezone";

// TimeParser updates all HTML elements with class '.convertTime', making them:
// - Human readable
// - Display time in current timezone
// - With context relevant data (e.g. today shows hour, last month just date)
// - Gives the element a title of the precise time with seconds (so hovering shows it)
// - If elements have classes '.preciseTime' or '.preciseTimeSeconds', includes extra specificity in output
// - If elements have class '.withPreposition' it includes preposition (to make time fit better in a sentence)
// - Requires elements have HTML content of a time string (e.g. a unix timestamp)
//
// Imported and initialized like this:
// if (!window.timeParser) { window.timeParser = new TimeParser() }
//
// To update an individual element with a time in it (doesn't require element to have class '.convertTime'):
// timeParser.writeTime(el)
//
// To get just the text that is output into the element:
// timeFromText("1604337131")
//
// You can add this to a react component:
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

  localizedDateText(time, preciseTime, includeSeconds, includePreposition) {
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
        this.hourFormat(time, "h:mm", includeSeconds, includePreposition)
      );
    }
    if (includePreposition) {
      prefix = "on ";
    }

    // If it's preciseTime (or preciseTimeSeconds), always show the hours and mins
    if (preciseTime || includeSeconds) {
      let hourStr = this.hourFormat(
        time,
        "h:mm",
        includeSeconds,
        includePreposition
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
      if (includePreposition) {
        return prefix + time.format("MMM Do");
      } else {
        return prefix + time.format("MMM Do");
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

  parse(text) {
    // If time is only a number, parse as a timestamp
    // Otherwise, parse as ISO_8601 which is the default time string
    if (/^\d+$/.test(text)) {
      return moment.unix(text);
    } else if (text !== null) {
      return moment(text, moment.ISO_8601);
    }
    if (text === null || !time.isValid()) {
      return null;
    }
  }

  // timeFromText() is not used, included to make getting the text output separately easier
  timeFromText(
    text,
    preciseTime = false,
    includeSeconds = false,
    includePreposition = false
  ) {
    return this.localizedDateText(
      this.parse(text),
      preciseTime,
      includeSeconds,
      includePreposition
    );
  }

  writeTime(el) {
    const text = el.textContent.trim();
    const time = this.parse(text);
    // So running this again doesn't reapply to this element
    el.classList.remove("convertTime");
    // So we know which were updated (for styling, future updates, etc)
    el.classList.add("convertedTime");

    // If we couldn't parse the time, exit
    if (!(text.length > 0) || time === null) {
      return;
    }

    el.innerHTML = this.localizedDateText(
      time,
      el.classList.contains("preciseTime"),
      el.classList.contains("preciseTimeSeconds"),
      el.classList.contains("withPreposition")
    );
    el.setAttribute("title", this.preciseTimeSeconds(time));
  }

  writeTimezone(el) {
    el.textContent = moment().format("z");
    el.classList.remove("convertTimezone");
  }

  localize() {
    // Write times
    Array.from(document.getElementsByClassName("convertTime")).forEach((el) =>
      this.writeTime(el)
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
