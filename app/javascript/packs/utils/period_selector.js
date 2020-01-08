import log from "../utils/log";

function PeriodSelector() {
  return {
    init() {
      this.enablePeriodSelection();
    },

    urlWithoutPeriod() {
      const newUrl = location.href
        .replace(/&?period=[^&]*/, "") // remove period
        .replace(/&?timezone=[^&]*/, "") // remove timezone
        .replace(/&?start_time=[^&]*/, "") // remove start_time
        .replace(/&?end_time=[^&]*/, "") // remove start_time
        .replace(/\?&/, "?") // replace ?& with just ?
        .replace(/&&/g, "&") // Grab &&, replace with single
        .replace(/(\?|&)$/, ""); // Grab ending ? or & - we don't need it

      const joiner = newUrl.match(/\?/) ? "&" : "?";
      return newUrl + joiner;
    },

    enableCustomSelection() {
      // Show the custom selection inputs
      $("#timeSelectionBtnGroup .period-select-standard").removeClass("active");
      $("#periodSelectCustom").addClass("active");
      $("#timeSelectionBtnGroup").addClass("custom-period-selected");
      $("#timeSelectionCustom").collapse("show");
    },

    disableCustomSelection() {
      $("#timeSelectionCustom").collapse("hide");
      $("#timeSelectionBtnGroup").removeClass("custom-period-selected");
    },

    submitCustomPeriodSelection() {
      const startTime = $("#start_time_selector").val();
      const endTime = $("#end_time_selector").val();
      return (location.href = `${this.urlWithoutPeriod()}period=custom&timezone=${
        window.localTimezone
      }&start_time=${startTime}&end_time=${endTime}`);
    },

    enablePeriodSelection() {
      const self = this;

      $("#timeSelectionBtnGroup button").on("click", function(e) {
        let period = $(e.target).attr("data-period");
        // Sometimes, the target isn't the button, it's something inside the button. In that case, find the correct period
        if (typeof period == "undefined") {
          // If we can't figure out what the target was, return false, so the user clicks again
          if (!$(e.target).parents("button").length) {
            return false;
          }
          period = $(e.target)
            .parents("button")
            .attr("data-period");
        }
        if (period === "custom") {
          log.debug("custom");
          return self.enableCustomSelection();
        } else {
          // Not really necessary, but makes it a little slicker
          self.disableCustomSelection();
        }
        return (location.href = `${self.urlWithoutPeriod()}period=${period}&timezone=${
          window.localTimezone
        }`);
      });

      $("#updatePeriodSelectCustom").on("click", function(e) {
        self.submitCustomPeriodSelection();
      });

      $("#timeSelectionCustom").on("submit", function(e) {
        self.submitCustomPeriodSelection();
        return false;
      });
    }
  };
}

export default PeriodSelector;
