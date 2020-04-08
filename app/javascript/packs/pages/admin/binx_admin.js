import log from "../../utils/log";
import moment from "moment-timezone";
import LoadFancySelects from "../../utils/load_fancy_selects.js";
import BinxAdminGraphs from "./graphs.js";
import BinxAdminBikesEdit from "./bikes_edit.js";
import BinxAdminRecoveryDisplayForm from "./recovery_display_form.js";
import BinxAdminInvoices from "./invoices.js";
import BinxAdminOrganizationForm from "./organization_form.js";
import BinxAdminBlogs from "./blogs.js";
import BinxAdminImageUploader from "./image_uploader.js";

function BinxAdmin() {
  return {
    init() {
      this.initAdminSearchSelect();
      // Enable bootstrap custom file upload boxes
      binxApp.enableFilenameForUploads();
      LoadFancySelects();

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
        binxAdminBikesEdit.init();
      }

      if ($("#admin_organizations_new, #admin_organizations_edit").length) {
        const $organizationForm = $("form").first();
        new BinxAdminOrganizationForm($organizationForm);
      }

      if ($("#multi-mnfg-selector").length) {
        this.bikesMultiManufacturerUpdate();
      }

      if ($("#blog-image-form").length > 0) {
        const binxAdminBlogs = BinxAdminBlogs();
        binxAdminBlogs.init();
      }
      if ($(".uppy").length > 0) {
        const binxAdminImageUploader = BinxAdminImageUploader();
        binxAdminImageUploader.init();
      }
      if ($("#stolenBikeImageEditing").length) {
        // Set a timeout so images have a bit to load
        setTimeout(this.fixStolenBikeImageWidth(this), 500);
      }
    },

    initAdminSearchSelect() {
      window.initialValue = $("#admin_other_navigation").val();
      // On change, if the change is for something new and is an actual value, redirect to that page
      $("#admin_other_navigation").on("change", (e) => {
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

    bikesMultiManufacturerUpdate() {
      window.toggleAllChecked = false;
      $("#multi-mnfg-selector").on("click", function(event) {
        event.preventDefault();
        window.toggleAllChecked = !window.toggleAllChecked;
        $(".update-mnfg-select input").prop("checked", window.toggleAllChecked);
      });
    },

    fixStolenBikeImageWidth() {
      // This was heinous, for reasons unknown
      let $promotedImages = $("#promoted-images-display");
      let $promotedImagesLi = $promotedImages.find("li");
      $promotedImages.css(
        "width",
        `${$promotedImagesLi.first().outerWidth() * $promotedImagesLi.length +
          20}px`
      );

      let $imageEdit = $("#stolenBikeImageEditing");
      let $imageEditLi = $imageEdit.find("li");
      $imageEdit.css(
        "width",
        `${$imageEditLi.first().outerWidth() * $imageEditLi.length + 40}px`
      );
    },
  };
}

export default BinxAdmin;
