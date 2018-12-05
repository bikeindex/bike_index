import * as log from "loglevel";
if (process.env.NODE_ENV != "production") log.setLevel("debug");

window.BinxAdmin = class BinxAdmin {
  init() {
    // If there is an element on the page with id pageContainerFluid, make the page container full width
    if ($("#pageContainerFluid").length) {
      $("#admin-content > .receptacle").css("max-width", "100%");
    }
  }
};
