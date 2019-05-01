
init(){

};

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
