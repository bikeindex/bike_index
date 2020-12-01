import log from "../../utils/log";
import moment from "moment-timezone";
import LoadFancySelects from "../../utils/load_fancy_selects.js";

export default class WalkrightupCustomer {
  constructor() {}
  init() {
    $("#updateLineStatus").on("click", (e) => {
      e.preventDefault();
      $(".updateLineStatusCollapse").collapse("toggle");
    });
  }
}
