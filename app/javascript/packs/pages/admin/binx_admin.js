import log from "../../utils/log";
import moment from "moment-timezone";
import LoadFancySelects from "../../utils/LoadFancySelects";
import BinxAdminGraphs from "./graphs.js"
import BinxAdminInvoices from "./invoices.js";


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
        const binxAdminGraphs = BinxAdminGraphs()
        binxAdminGraphs.init()
      }
      if ($("#use_image_for_display").length > 0) {
        this.useBikeImageForDisplay();
      }
      if ($("#admin-locations-fields").length > 0) {
        this.adminLocations();
      }
      if ($(".inputTriggerRecalculation")) {
        const binxAdminInvoices = BinxAdminInvoices();
        binxAdminInvoices.init();
      }
      if ($("#admin-recovery-fields")) {
        this.bikesEditRecoverySlide();
      }
      // Enable bootstrap custom file upload boxes
      binxApp.enableFilenameForUploads();
      LoadFancySelects();

      this.enablePeriodSelection();
    },

    // Non Fast Attr bikes edit
    bikesEditRecoverySlide() {
      const $this = $("#bike_stolen");
      $this.on("change", e => {
        e.preventDefault();
        if ($this.prop("checked")) {
          $("#admin-recovery-fields").slideUp();
        } else {
          $("#admin-recovery-fields").slideDown();
        }
      });
    },

    // Bike Recoveries
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

    // Orgs location adding method
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
    }
  };
}

export default BinxAdmin;
