// This COPIES app/javascript/scripts/utils/time_parser.js
// ... with a two modifications:
//
// - It relies on rails-assets-moment-timezone (not package.js)
// - It doesn't use 'export default' (not supported by sprockets)
//
//
// To re-import time_parser.js:
//
// 1. Copy the contents of that file below
// 2. Delete everything before "class TimeParser"
//    (specifically "import ..." and "export default")
//

class TimeParser {
  constructor() {
    if (!window.localTimezone) {
      window.localTimezone = moment.tz.guess();
    }
    this.singleFormat = !!window.timeParserSingleFormat;
    this.localTimezone = window.localTimezone;
    moment.tz.setDefault(this.localTimezone);
    this.yesterdayStart = moment().subtract(1, "day").startOf("day");
    this.todayStart = moment().startOf("day");
    this.todayEnd = moment().endOf("day");
    this.tomorrowEnd = moment().add(1, "day").endOf("day");
    this.todayYear = moment().year();
  }

  // Directly render localized time elements. Returns an HTML string
  localizedTimeHtml(
    timeString,
    { singleFormat, preciseTime, includeSeconds, withPreposition }
  ) {
    const time = this.parse(String(timeString).trim());

    if (time === null) {
      return `<span></span>`;
    }
    // If singleFormat was passed as true, override with that, otherwise default to window format
    let variableFormat = singleFormat ? false : !this.singleFormat;

    return `<span title="${this.preciseTimeSeconds(
      time
    )}">${this.localizedDateText(
      time,
      !variableFormat,
      preciseTime,
      includeSeconds,
      withPreposition
    )}</span>`;
  }

  // Update all the times (and timezones) on the page
  // Removes the classes that trigger localization, so it doesn't reupdate the times
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

    // Write local time in fields
    Array.from(
      document.getElementsByClassName("dateInputUpdateZone")
    ).forEach((el) => this.setDateInputField(el));
  }

  // ---------
  // Methods below here are internal methods
  // ---------

  // Update an element with the current time.
  // Requires the element have parseable text of a time, pulls properties from the element classes
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
      // If the window has singleFormat, then it should be single format - unless the element has variableFormat class
      this.singleFormat ? !el.classList.contains("variableFormat") : false,
      el.classList.contains("preciseTime"),
      el.classList.contains("preciseTimeSeconds"),
      el.classList.contains("withPreposition")
    );
    el.setAttribute("title", this.preciseTimeSeconds(time));
  }

  // If we're display time with the hour, we have different formats based on whether we include seconds
  // this manages that functionality
  hourFormat(time, baseTimeFormat, includeSeconds, withPreposition) {
    const prefix = withPreposition ? " at " : "";
    if (includeSeconds) {
      return `${prefix}${time.format(baseTimeFormat)}:<small>${time.format(
        "ss"
      )}</small> ${time.format("a")}`;
    } else {
      return prefix + time.format(`${baseTimeFormat}a`);
    }
  }

  localizedDateText(
    time,
    singleFormat,
    preciseTime,
    includeSeconds,
    withPreposition
  ) {
    let prefix = "";
    // If we're doing inconsistent formatting, add a prefix if we're dealing with yesterday or today (not the future)
    if (
      !singleFormat &&
      time < this.tomorrowEnd &&
      time > this.yesterdayStart
    ) {
      // If we're dealing with yesterday or tomorrow, we prepend that
      if (time < this.todayStart) {
        prefix = "Yesterday ";
      } else if (time > this.todayEnd) {
        prefix = "Tomorrow ";
      }
      return (
        prefix + this.hourFormat(time, "h:mm", includeSeconds, withPreposition)
      );
    }
    if (withPreposition) {
      prefix = "on ";
    }

    // If it's preciseTime (or preciseTimeSeconds), always show the hours and mins
    if (preciseTime || includeSeconds) {
      // Make the time less-strong, otherwise it's hard to separate from the date
      let hourEl = `<span class="less-strong">${this.hourFormat(
        time,
        "h:mm",
        includeSeconds,
        withPreposition
      )}</span>`;
      // Only show the year if it isn't this year
      if (singleFormat || time.year() - this.todayYear !== 0) {
        return prefix + time.format("YYYY-MM-DD ") + hourEl;
      } else {
        return prefix + time.format("MMM Do ") + hourEl;
      }
    }
    // Otherwise, format in basic format
    if (singleFormat || time.year() - this.todayYear !== 0) {
      return prefix + time.format("YYYY-MM-DD");
    } else {
      if (withPreposition) {
        return prefix + time.format("MMM Do");
      } else {
        return prefix + time.format("MMM Do");
      }
    }
  }

  preciseTimeSeconds(time) {
    return time.format("YYYY-MM-DD h:mm:ss a");
  }

  setHiddenTimezoneFields(el) {
    el.value = this.localTimezone;
  }

  setDateInputField(el) {
    const text = el.getAttribute("data-initialtime")
    if (text.length > 0) {
      // Format that at least Chrome expects for field
      el.value = moment(text, moment.ISO_8601).format("YYYY-MM-DDTHH:mm")
    }
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

  writeTimezone(el) {
    el.textContent = moment().format("z");
    el.classList.remove("convertTimezone");
  }
}
