import "@hotwired/turbo-rails";

// Import stimulus controllers
import { Application } from "@hotwired/stimulus";
// Lazy load all controllers
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading";

import TimeLocalizer from "utils/time_localizer";

/* global Turbo */
// Disable Turbo by default, only enable on case-by-case
// You must include data-turbo="true" on the elements you want to enable turbo on
Turbo.session.drive = false;
const application = Application.start();

// Configure Stimulus development experience
application.debug = false;
window.Stimulus = application;

lazyLoadControllersFrom("components", application);

function localizeTime() {
  console.log("localizeTime!");
  if (!window.timeLocalizer) window.timeLocalizer = new TimeLocalizer();
  window.timeLocalizer.localize();
}

document.addEventListener("DOMContentLoaded", localizeTime);
document.addEventListener("turbo:render", localizeTime);
