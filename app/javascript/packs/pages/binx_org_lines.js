import log from "../utils/log";

export default class BinxAppOrgLines {
  init() {
    const updateCellDisplay = this.updateCellDisplay;
    $("#toggleUpdateMultiple").on("click", function (e) {
      e.preventDefault();
      // :( - it's on the window, but we can't import it here because we're in the old views
      window.$(".showOnMultiSelect").collapse("toggle");
      $("#toggleUpdateMultiple").toggleClass("showingMultiSelect");
      // Because this is an old version of bootstrap, it doesn't make the table cells table cells
      // so callback afterward to fix the display. Basically total bullshit
      setTimeout(updateCellDisplay, 500);
    });

    $("#selectAllSelector").on("click", function (e) {
      e.preventDefault();
      window.toggleAllChecked = !window.toggleAllChecked;
      $(".multiselect-cell input").prop("checked", window.toggleAllChecked);
    });
  }

  updateCellDisplay() {
    if ($("#toggleUpdateMultiple").hasClass("showingMultiSelect")) {
      $(".multiselect-cell").css("display", "table-cell");
    } else {
      $(".multiselect-cell").css("display", "none");
    }
  }
}
