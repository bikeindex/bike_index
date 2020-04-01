import log from "../utils/log";

export default class BinxAppOrgExport {
  init() {
    log.debug("dddd");

    $(".dayClosedCheckbox").on("change", e => {
      let $schedulingDay = $(e.target).parents(".scheduling-day");
      let day = schedulingDay.attr("data-day");
      log.debug(schedulingDay, day);
      if ($schedulingDay.find().prop("checked", true)) {
        $schedulingDay.find(".dayOpen").collapse("show");
      } else {
        $schedulingDay.find(".dayOpen").collapse("hide");
      }
      this.updateSchedule();
    });
  }

  updateSchedule() {
    log.debug("schedule updated");
  }
}
