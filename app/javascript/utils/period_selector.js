import log from "./log";

function PeriodSelector() {
  return {
    init() {
      this.autoSubmit = !(
        $("#timeSelectionBtnGroup").attr("data-nosubmit") == "true"
      );
      this.enablePeriodSelection();
    },

    urlParamsWithoutPeriod() {
      const urlParams = new URLSearchParams(window.location.search);
      urlParams.delete("period");
      urlParams.delete("timezone");
      urlParams.delete("start_time");
      urlParams.delete("end_time");
      urlParams.append("timezone", window.localTimezone);
      return urlParams;
    },

    urlParamsWithNewPeriod(selectedPeriod = null) {
      // If it's null, empty, undefined or anything other than string
      if (typeof selectedPeriod !== "string") {
        // If not passed the period, Figure it out, defaulting to all
        selectedPeriod =
          $("#timeSelectionBtnGroup .btn.active").attr("data-period") || "all";
      }

      const urlParams = this.urlParamsWithoutPeriod();
      urlParams.append("period", selectedPeriod);

      if (selectedPeriod === "custom") {
        urlParams.append("start_time", $("#start_time_selector").val());
        urlParams.append("end_time", $("#end_time_selector").val());
      }
      return urlParams;
    },

    enableCustomSelection() {
      // Show the custom selection inputs
      $("#timeSelectionBtnGroup .period-select-standard").removeClass("active");
      $("#periodSelectCustom").addClass("active");
      $("#timeSelectionBtnGroup").addClass("custom-period-selected");
      // Sometimes bootstrap isn't loaded
      if (typeof $().collapse == "function") {
        $("#timeSelectionCustom").collapse("show");
      } else {
        $("#timeSelectionCustom").addClass("in");
        $("#timeSelectionCustom").css("display", "flex");
      }
    },

    disableCustomSelection() {
      if (typeof $().collapse == "function") {
        $("#timeSelectionCustom").collapse("hide");
      } else {
        $("#timeSelectionCustom").removeClass("in");
        $("#timeSelectionCustom").css("display", "none");
      }
      $("#timeSelectionBtnGroup").removeClass("custom-period-selected");
    },

    urlForPeriod(selectedPeriod = null) {
      return (
        window.location.origin +
        location.pathname +
        "?" +
        this.urlParamsWithNewPeriod(selectedPeriod).toString()
      );
    },

    enablePeriodSelection() {
      const self = this;

      $("#timeSelectionBtnGroup button").on("click", (e) => {
        let $target = $(e.target);
        let selectedPeriod = $target.attr("data-period");
        // Sometimes, the target isn't the button, it's something inside the button. In that case, find the correct period
        if (typeof selectedPeriod == "undefined") {
          // If we can't figure out what the target was, return false, so the user clicks again
          if (!$(e.target).parents("button").length) {
            return false;
          }
          $target = $target.parents("button");
          selectedPeriod = $target.attr("data-period");
        }
        if (selectedPeriod === "custom") {
          return self.enableCustomSelection();
        } else {
          // Not really necessary, but makes it a little slicker
          self.disableCustomSelection();
        }
        $("#timeSelectionBtnGroup .period-select-standard.active").removeClass(
          "active"
        );
        $target.addClass("active");
        if (self.autoSubmit) {
          return (location.href = self.urlForPeriod(selectedPeriod));
        } else {
          // log.debug(self.urlForPeriod(selectedPeriod));
          return true;
        }
      });

      // If not autosubmitting, this needs to be managed separately
      if (self.autoSubmit) {
        $("#timeSelectionCustom").on("submit", (e) => {
          location.href = self.urlForPeriod("custom");
          return false;
        });
      }
    },
  };
}

export default PeriodSelector;
