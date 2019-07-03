import log from "../../utils/log";
import moment from "moment-timezone";
import LoadFancySelects from "../../utils/load_fancy_selects.js";
import BinxAdminGraphs from "./graphs.js";
import BinxAdminBikesEdit from "./bikes_edit.js";
import BinxAdminRecoveryDisplayForm from "./recovery_display_form.js";
import BinxAdminInvoices from "./invoices.js";
import BinxAdminOrganizationForm from "./organization_form.js";

function BinxAdmin() {
  return {
    init() {
      this.initAdminSearchSelect();
      // Enable bootstrap custom file upload boxes
      binxApp.enableFilenameForUploads();
      LoadFancySelects();
      this.enablePeriodSelection();

      if ($(".calendar-box")[0]) {
        const binxAdminGraphs = BinxAdminGraphs();
        binxAdminGraphs.init();
      }

      if ($("#recovery-display-form").length) {
        const binxAdminRecoveryDisplayForm = BinxAdminRecoveryDisplayForm();
        binxAdminRecoveryDisplayForm.init();
      }

      if ($("#admin-locations-fields").length) {
        this.adminLocations();
      }

      if ($(".inputTriggerRecalculation").length) {
        const binxAdminInvoices = BinxAdminInvoices();
        binxAdminInvoices.init();
      }

      if ($("#admin_bikes_edit").length) {
        const binxAdminBikesEdit = BinxAdminBikesEdit();
        binxAdminBikesEdit.init()
      }

      if ($("#admin_organizations_new, #admin_organizations_edit").length) {
        const $organizationForm = $("form").first();
        new BinxAdminOrganizationForm($organizationForm);
      }

      if ($("#multi-mnfg-selector").length) {
        this.bikesMultiManufacturerUpdate();
      }
    },

    initAdminSearchSelect() {
      window.initialValue = $("#admin_other_navigation").val();
      // On change, if the change is for something new and is an actual value, redirect to that page
      $("#admin_other_navigation").on("change", e => {
        let newValue = $("#admin_other_navigation").val();
        if (newValue != window.initialValue && newValue.length > 0) {
          location.href = newValue;
        }
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
    },

    bikesMultiManufacturerUpdate() {
      window.toggleAllChecked = false;
      $("#multi-mnfg-selector").on("click", function(event) {
        event.preventDefault();
        window.toggleAllChecked = !window.toggleAllChecked;
        $(".update-mnfg-select input").prop("checked", window.toggleAllChecked);
      });
    }
  };
}

export default BinxAdmin;
