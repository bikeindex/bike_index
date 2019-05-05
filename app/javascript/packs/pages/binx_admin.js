import log from "../utils/log";
import moment from "moment-timezone";
import LoadFancySelects from "../utils/LoadFancySelects";

function BinxAdmin() {
  return {
    init() {
      // If there is an element on the page with id pageContainerFluid, make the page container full width
      if ($("#pageContainerFluid").length) {
        $("#admin-content > .receptacle").css("max-width", "100%");
      } else {
        // Also, make full-screen-table receptacle max-width
        $(".full-screen-table")
          .parents(".receptacle")
          .css("max-width", "100%");
      }
      if ($(".calendar-box")[0]) {
        this.setCustomGraphStartAndSlide();
        this.changeGraphCalendarBox();
      }
      if ($("#use_image_for_display").length > 0) {
        this.useBikeImageForDisplay();
      }
      if ($("#admin-locations-fields").length > 0) {
        this.adminLocations();
      }
      if ($(".inputTriggerRecalculation")) {
        this.initializeInvoiceForm();
        this.updateInvoiceCalculations();
      }
      // Enable bootstrap custom file upload boxes
      binxApp.enableFilenameForUploads();
      LoadFancySelects();

      this.enablePeriodSelection();
    },

    changeGraphCalendarBox() {
      $("select#graph_date_option").on("change", e => {
        e.preventDefault();
        this.setCustomGraphStartAndSlide();
      });
    },

    startGraphTimeSet() {
      const graphSelected = $("select#graph_date_option")[0].value.split(",");
      const amount = Number(graphSelected[0]);
      const unit = graphSelected[1];
      $("#start_at").val(
        moment()
          .subtract(amount, unit)
          .format("YYYY-MM-DDTHH:mm")
      );
    },

    setCustomGraphStartAndSlide() {
      if ($("select#graph_date_option")[0].value === "custom") {
        $(".calendar-box").slideDown();
      } else {
        $(".calendar-box").slideUp();
        this.startGraphTimeSet();
      }
    },

    useBikeImageForDisplay() {
      $("#use_image_for_display").on("click", e => {
        e.preventDefault();
        const image_btn = $("#use_image_for_display");
        if (image_btn.hasClass("using_bikes")) {
          $("#recovery-photo-upload-input").slideDown();
          $("#recovery_display_remote_image_url").val("");
          image_btn.text("Use first image");
        } else {
          $("#recovery-photo-upload-input").slideUp();
          $("#recovery_display_remote_image_url").val(
            image_btn.attr("data-url")
          );
          image_btn.text("nvrmind");
        }
        return image_btn.toggleClass("using_bikes");
      });
    },

    adminLocations() {
      $("form").on("click", ".remove_fields", function(event) {
        // We don't need to do anything except slide the input up, because the label is on it.
        return $(this)
          .closest("fieldset")
          .slideUp();
      });
      return $("form").on("click", ".add_fields", function(event) {
        const time = new Date().getTime();
        const regexp = new RegExp($(this).data("id"), "g");
        $(this).before(
          $(this)
            .data("fields")
            .replace(regexp, time)
        );
        event.preventDefault();
        LoadFancySelects();
      });
    },

    enablePeriodSelection() {
      $("#timeSelectionBtnGroup button").on("click", function(e) {
        let joiner;
        const period = $(e.target).attr("data-period");
        const current_url = location.href.replace(/&?period=[^&]*/, "");
        if (current_url.match(/\?/)) {
          joiner = "&";
        } else {
          joiner = "?";
        }
        return (location.href = `${current_url}${joiner}period=${period}`);
      });
    },

    initializeInvoiceForm() {
      this.updateInvoiceCalculations();
      $(".inputTriggerRecalculation").on("change paste keyup", e =>
        this.updateInvoiceCalculations()
      );
      $("#invoiceForm .paidFeatureCheck input").on("change", e =>
        this.updateInvoiceCalculations()
      );
    },

    updateInvoiceCalculations() {
      let oneTimeCost, recurringCost;
      const recurring = $(".paidFeatureCheck input.recurring:checked")
        .get()
        .map(i => parseInt($(i).attr("data-amount"), 10));
      if (recurring.length > 0) {
        recurringCost = recurring.reduce((x, y) => x + y);
      } else {
        recurringCost = 0;
      }
      const oneTime = $(".paidFeatureCheck input.oneTime:checked")
        .get()
        .map(i => parseInt($(i).attr("data-amount"), 10));
      if (oneTime.length > 0) {
        oneTimeCost = oneTime.reduce((x, y) => x + y);
      } else {
        oneTimeCost = 0;
      }
      $("#recurringCount").text(recurring.length);
      $("#oneTimeCount").text(oneTime.length);
      $("#recurringCost").text(`${recurringCost}.00`);
      $("#oneTimeCost").text(`${oneTimeCost}.00`);
      $("#totalCost").text(`${recurringCost + oneTimeCost}.00`);
      const due = parseInt($("#invoice_amount_due").val(), 10);
      $("#discountCost").text(`${-1 * (recurringCost + oneTimeCost - due)}.00`);

      const checked_ids = $(".paidFeatureCheck input:checked")
        .get()
        .map(i => $(i).attr("data-id"));
      $("#invoice_paid_feature_ids").val(checked_ids);
    }
  };
}

export default BinxAdmin;
