import log from "../utils/log";

function PeriodSelector() {
  return {
    init() {
      this.enablePeriodSelection();
    },

    urlWithoutPeriod() {
      return location.href
        .replace(/&?period=[^&]*/, "") // Grab period=
        .replace(/&?timezone=[^&]*/, "") // Grab timezone=
        .replace(/\?&/, "?") // replace ?& with just ?
        .replace(/&&/g, "&") // Grab &&, replace with single
        .replace(/(\?|&)$/, ""); // Grab ending ? or & - we don't need it
    },

    urlWithoutPeriodJoiner() {
      return this.urlWithoutPeriod().match(/\?/) ? "&" : "?";
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
      return (location.href = `${this.urlWithoutPeriod()}${this.urlWithoutPeriodJoiner()}period=custom&timezone=${
        window.localTimezone
      }&start_time=${startTime}&end_time=${endTime}`);
    },

    enablePeriodSelection() {
      const self = this;

      $("#timeSelectionBtnGroup button").on("click", function(e) {
        const period = $(e.target).attr("data-period");
        if (period === "custom") {
          return self.enableCustomSelection();
        } else {
          // Not really necessary, but makes it a little slicker
          self.disableCustomSelection();
        }
        return (location.href = `${self.urlWithoutPeriod()}${self.urlWithoutPeriodJoiner()}period=${period}&timezone=${
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
