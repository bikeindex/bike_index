import * as log from "loglevel";
if (process.env.NODE_ENV != "production") log.setLevel("debug");
import moment from "moment-timezone";

window.BinxAdmin = class BinxAdmin {
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
      window.binxAdmin.setCustomGraphStartAndSlide();
      this.changeGraphCalendarBox();
    }
    if ($("#use_image_for_display").length > 0) {
      this.useBikeImageForDisplay();
    }
    // Enable bootstrap custom file upload boxes
    binxApp.enableFilenameForUploads();
  }

  changeGraphCalendarBox() {
    $("select#graph_date_option").on("change", e => {
      e.preventDefault();
      this.setCustomGraphStartAndSlide();
    });
  }

  startGraphTimeSet() {
    let graphSelected = $("select#graph_date_option")[0].value.split(",");
    let amount = Number(graphSelected[0]);
    let unit = graphSelected[1];
    $("#start_at").val(
      moment()
        .subtract(amount, unit)
        .format("YYYY-MM-DDTHH:mm")
    );
  }

  setCustomGraphStartAndSlide() {
    if ($("select#graph_date_option")[0].value === "custom") {
      $(".calendar-box").slideDown();
    } else {
      $(".calendar-box").slideUp();
      this.startGraphTimeSet();
    }
  }
  useBikeImageForDisplay(){
    $("#use_image_for_display").on("click", e => {
      e.preventDefault()
      var imageBtn = $('#use_image_for_display');
      if (imageBtn.hasClass('using_bikes')) {
        $('.avatar-upload').slideDown();
        $('#recovery_display_remote_image_url').val('');
        imageBtn.text('Use first image');
      } else {
        $('.avatar-upload').slideUp();
        $('#recovery_display_remote_image_url').val(imageBtn.attr('data-url'));
        imageBtn.text('nvrmind');
      }
      return imageBtn.toggleClass('using_bikes');
    })
  }
};


