import log from "../utils/log";
import moment from "moment-timezone";
import LoadFancySelects from "../utils/LoadFancySelects";

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
    if ($("#admin-locations-fields").length > 0){
    this.adminLocations()
    }
    // Enable bootstrap custom file upload boxes
    binxApp.enableFilenameForUploads();
    LoadFancySelects();
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

  useBikeImageForDisplay() {
    $("#use_image_for_display").on("click", e => {
      e.preventDefault();
      const image_btn = $("#use_image_for_display");
      if (image_btn.hasClass("using_bikes")) {
        $("#recovery_display_remote_image_url").val("");
        image_btn.text("Use first image");
      } else {
        $("#recovery_display_remote_image_url").val(image_btn.attr("data-url"));
        image_btn.text("nvrmind");
      }
      return image_btn.toggleClass("using_bikes");
    });
  }
  adminLocations() {
    $('form').on('click', '.remove_fields', function(event) {
      // We don't need to do anything except slide the input up, because the label is on it.
      return $(this).closest('fieldset').slideUp();
    });
      // event.preventDefault()
    return $('form').on('click', '.add_fields', function(event) {
      const time = new Date().getTime();
      const regexp = new RegExp($(this).data('id'), 'g');
      $(this).before($(this).data('fields').replace(regexp, time));
      event.preventDefault();
      const us_val = parseInt($('#us-country-code').text(), 10);
      for (let location of Array.from($(this).closest('fieldset').find('.country_select_container select'))) {
        const l = $(location);
        if (!(l.val().length > 0)) { l.val(us_val); }
      }
      const names = $(this).closest('fieldset').find('.location-name-field input');
      for (let name of Array.from(names)) {
        const n = $(name);
        if (!(n.val().length > 0)) { n.val($('#organization_name').val()); }
      }

      return $('.chosen-select select').select2();
    });
  }
};
