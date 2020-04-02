import log from "../utils/log";

export default class BinxAppOrgExport {
  init() {
    $(".dayClosedCheckbox").on("change", e => {
      let $schedulingDay = $(e.target).parents(".scheduling-day");
      let day = $schedulingDay.attr("data-day");
      let showOrHide = $schedulingDay.find(".dayClosedCheckbox").prop("checked")
        ? "hide"
        : "show";
      this.collapseEl($schedulingDay.find(".dayOpen"), showOrHide);
      this.updateSchedule();
    });
  }

  collapseEl($el, showOrHide) {
    // Fuck this lack of bootstrap in here
    if (typeof $().collapse == "function") {
      $el.collapse(showOrHide);
    } else {
      if (showOrHide == "show") {
        $el.slideDown("fast");
        // $el.addClass("in");
        // $el.css("display", "flex");
      } else {
        $el.slideUp("fast");
        // $el.removeClass("in");
        // $el.css("display", "none");
      }
    }
  }

  updateSchedule() {
    log.debug("schedule updated");
  }
}
