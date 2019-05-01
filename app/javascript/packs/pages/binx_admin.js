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
      if ($("#bike_stolen").length > 0) {
        this.bikesEditRecoverySlide();
      }
      if ($("#frame-sizer").length > 0) {
        this.updateFrameSize();
        this.setFrameSize();
        this.fixieSlide();
      }
      // Enable bootstrap custom file upload boxes
      binxApp.enableFilenameForUploads();
      LoadFancySelects();
    },

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

    setFrameSize() {
      const unit = $("#bike_frame_size_unit").val();
      if (unit !== "ordinal" && unit.length > 0) {
        $("#frame-sizer .hidden-other")
          .slideDown()
          .addClass("unhidden");
        return $("#frame-sizer .groupedbtn-group").addClass("ex-size");
      }
    },

    updateFrameSize() {
      $("#frame-sizer").on("click", e => {
        e.preventDefault();
        const size = $(e.target).attr("data-size");
        const hidden_other = $("#frame-sizer .hidden-other");
        if (size === "cm" || size === "in") {
          $("#bike_frame_size_unit").val(size);
          if (!hidden_other.hasClass("unhidden")) {
            hidden_other.slideDown("fast").addClass("unhidden");
            $("#bike_frame_size").val("");
            $("#bike_frame_size_number").val("");
            return $("#frame-sizer .groupedbtn-group").addClass("ex-size");
          }
        } else {
          $("#bike_frame_size_unit").val("ordinal");
          $("#bike_frame_size_number").val("");
          $("#bike_frame_size").val(size);
          if (hidden_other.hasClass("unhidden")) {
            hidden_other.removeClass("unhidden").slideUp("fast");
            return $("#frame-sizer .groupedbtn-group").removeClass("ex-size");
          }
        }
      });
    },

    fixieSlide() {
      $("#fixed_fixed").on("change", e => {
        if ($("#fixed_fixed").prop("checked")){
          $("#not-fixed").slideUp();
        } else {
          $("#not-fixed").slideDown();
        }
      })
    }
  };
}

export default BinxAdmin;
