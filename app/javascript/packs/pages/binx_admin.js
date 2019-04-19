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
        setCustomGraphStartAndSlide();
        changeGraphCalendarBox();
      }
      if ($("#use_image_for_display").length > 0) {
        useBikeImageForDisplay();
      }
      // Enable bootstrap custom file upload boxes
      binxApp.enableFilenameForUploads();
      LoadFancySelects();
    },

    changeGraphCalendarBox() {
      $("select#graph_date_option").on("change", e => {
        e.preventDefault();
        setCustomGraphStartAndSlide();
      });
    },

    startGraphTimeSet() {
      let graphSelected = $("select#graph_date_option")[0].value.split(",");
      let amount = Number(graphSelected[0]);
      let unit = graphSelected[1];
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
        startGraphTimeSet();
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
          $("#recovery_display_remote_image_url").val(image_btn.attr("data-url"));
          image_btn.text("nvrmind");
        }
        return image_btn.toggleClass("using_bikes");
      });
    }
  }
};

export default BinxAdmin;
