// TODO: add ability to show in og time zone
// 2024-11-24 - refactor code to better take advantage of luxon
// 2024-11-13 - switch moment to luxon!
// 2023-8-25 - Updated withPreposition
// 2023-7-30 - Added setDateInputField

import { DateTime } from 'luxon'

// TimeLocalizer updates all HTML elements with class '.convertTime', making them:
// - Human readable
// - Displayed with time in provided timezone
// - With context relevant data (e.g. today shows hour, last month just date)
// - Gives the element a title of the precise time with seconds (so hovering shows it) - unless it has the class skipTimeTitle
// - If elements have classes '.preciseTime' or '.preciseTimeSeconds', includes extra specificity in output
// - If elements have class '.withPreposition' it includes preposition (to make time fit better in a sentence)
// - Requires elements have HTML content of a time string (e.g. a unix timestamp)
// - if the window has timeLocalizerSingleFormat truthy, all times are a single format, for consistency
//   ... except elements that have classes '.variableFormat'
//
// Imported and initialized like this:
// if (!window.timeLocalizer) { window.timeLocalizer = new TimeLocalizer() }
// window.timeLocalizer.localize() // updates all the elements on the page with the localized time
//
// To get span with the localized time:
// localizedTimeHtml("1604337131", {})
//
// You can add this to a react component:
// componentDidUpdate() { window.timeLocalizer.localize() }

export default class TimeLocalizer {
  constructor () {
    if (!window.localTimezone) {
      window.localTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone
    }
    this.singleFormat = !!window.timeLocalizerSingleFormat
    this.localTimezone = window.localTimezone
    // Create all DateTime instances with the local timezone
    this.now = DateTime.local().setZone(this.localTimezone)
    this.yesterdayStart = this.now.minus({ days: 1 }).startOf('day') - 1
    this.todayStart = this.now.startOf('day')
    this.todayEnd = this.now.endOf('day')
    this.tomorrowEnd = this.now.plus({ days: 1 }).endOf('day')
    this.todayYear = this.now.year
  }

  // Directly render localized time elements. Returns an HTML string
  localizedTimeHtml (
    timeString,
    { singleFormat, preciseTime, includeSeconds, withPreposition }
  ) {
    const time = this.parse(String(timeString).trim())

    if (time === null) {
      return '<span></span>'
    }
    // If singleFormat was passed as true, override with that, otherwise default to window format
    const variableFormat = singleFormat ? false : !this.singleFormat

    return `<span title="${this.preciseTimeSeconds(
      time
    )}">${this.localizedDateText(
      time,
      !variableFormat,
      preciseTime,
      includeSeconds,
      withPreposition
    )}</span>`
  }

  // Update all the times (and timezones) on the page
  // Removes the classes that trigger localization, so it doesn't reupdate the times
  localize () {
    // Write times
    Array.from(document.getElementsByClassName('convertTime')).forEach((el) =>
      this.writeTime(el)
    )

    // Write timezones
    Array.from(
      document.getElementsByClassName('convertTimezone')
    ).forEach((el) => this.writeTimezone(el))

    // Write hidden timezone fields - so if we're submitting a form, it includes the current timezone
    Array.from(
      document.getElementsByClassName('hiddenFieldTimezone')
    ).forEach((el) => this.setHiddenTimezoneFields(el))

    // Write local time in fields
    Array.from(
      document.getElementsByClassName('dateInputUpdateZone')
    ).forEach((el) => this.setDateInputField(el))
  }

  // ---------
  // Methods below here are internal methods
  // ---------

  // Update an element with the current time.
  // Requires the element have parseable text of a time, pulls properties from the element classes
  writeTime (el) {
    const text = el.textContent.trim()
    const time = this.parse(text)
    // So running this again doesn't reapply to this element
    el.classList.remove('convertTime')
    // So we know which were updated (for styling, future updates, etc)
    el.classList.add('convertedTime')

    // If we couldn't parse the time, exit
    if (!(text.length > 0) || time === null) {
      return
    }
    el.innerHTML = this.localizedDateText(
      time,
      // If the window has singleFormat, then it should be single format - unless the element has variableFormat class
      this.singleFormat ? !el.classList.contains('variableFormat') : false,
      el.classList.contains('preciseTime'),
      el.classList.contains('preciseTimeSeconds'),
      el.classList.contains('withPreposition')
    )
    if (!el.classList.contains('skipTimeTitle')) {
      el.setAttribute('title', this.preciseTimeSeconds(time))
    }
  }

  // If we're display time with the hour, we have different formats based on whether we include seconds
  // this manages that functionality
  hourFormat (time, baseTimeFormat, includeSeconds, withPreposition) {
    const prefix = withPreposition ? ' at ' : ''
    if (includeSeconds) {
      return `${prefix}${time.toFormat(baseTimeFormat)}:<small>${time.toFormat(
        'ss'
      )}</small> ${time.toFormat('a')}`
    } else {
      return prefix + time.toFormat(`${baseTimeFormat} a`)
    }
  }

  localizedDateText (
    time,
    singleFormat,
    preciseTime,
    includeSeconds,
    withPreposition
  ) {
    const currentThreeDays = (time < this.tomorrowEnd && time > this.yesterdayStart)

    // If it's preciseTime (or preciseTimeSeconds), always show the hours and mins
    let hourEl = (preciseTime || includeSeconds || currentThreeDays) ? ` ${this.hourFormat(time, 'h:mm', includeSeconds, withPreposition)}` : ''

    if (singleFormat) {
      return time.toFormat('yyyy-MM-dd') + hourEl
    }

    // If not withPreposition, include a comma
    if (!withPreposition && hourEl.length > 0) {
      hourEl = ', ' + hourEl
    }

    let prefix = ''
    // If we're doing inconsistent formatting, add a prefix if we're dealing with yesterday or today (not the future)
    if (currentThreeDays) {
      // If we're dealing with yesterday or tomorrow, we prepend that
      if (time < this.todayStart) {
        prefix = 'Yesterday'
      } else if (time > this.todayEnd) {
        prefix = 'Tomorrow'
      } else {
        prefix = 'Today'
      }
      return (
        // Always return yday, today, tomorrow with hours
        prefix + hourEl
      )
    }

    // Only show the year if it isn't this year
    if (time.year - this.todayYear !== 0) {
      return prefix + time.toLocaleString({ month: 'short', day: 'numeric', year: 'numeric' }) + hourEl
    } else {
      return prefix + time.toLocaleString({ month: 'short', day: 'numeric' }) + hourEl
    }
  }

  preciseTimeSeconds (time) {
    return time.toLocaleString(DateTime.DATETIME_FULL_WITH_SECONDS)
  }

  setHiddenTimezoneFields (el) {
    el.value = this.localTimezone
  }

  setDateInputField (el) {
    const text = el.getAttribute('data-initialtime')
    if (text.length > 0) {
      // Format that at least Chrome expects for field
      el.value = DateTime.fromISO(text).toFormat('yyyy-MM-dd\'T\'HH:mm')
    }
  }

  parse (text) {
    // If time is only a number, parse as a timestamp
    // Otherwise, parse as ISO_8601 which is the default time string
    if (/^\d+$/.test(text)) {
      return DateTime.fromSeconds(parseInt(text))
    } else if (text !== null) {
      return DateTime.fromISO(text)
    }
    // REMOVED time.isValid because time isn't defined
    if (text === null) {
      return null
    }
  }

  writeTimezone (el) {
    el.textContent = this.now.toFormat('z')
    el.classList.remove('convertTimezone')
  }
}
