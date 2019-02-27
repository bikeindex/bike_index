/* eslint no-console:0 */

// This is the same as application.js pack - except that it adds rails-ujs and makes jquery globally available.
// TODO: Once the coffeescript has been converted and everything is in webpack, the application.js pack should look like this
//       and this can be removed

import Rails from "rails-ujs";
import "bootstrap/dist/js/bootstrap";

Rails.start();

import "../source/javascript/initializer.js";

// Add jQuery to the window so it's accessible in the console, and just in general
window.$ = window.jQuery = jQuery;
