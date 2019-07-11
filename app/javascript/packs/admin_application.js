/* eslint-disable */

// This is the same as application.js pack - except that it adds rails-ujs and makes jquery globally available.
// TODO: Once the coffeescript has been converted and everything is in webpack, the application.js pack should look like this
//       and this can be removed

import Rails from "rails-ujs";
import "bootstrap/dist/js/bootstrap";
import "./pages/initializer";

Rails.start();

// And also include chartkick
import Chartkick from "chartkick";
window.Chartkick = Chartkick;
import Chart from "chart.js";
Chartkick.addAdapter(Chart);

// Add jQuery to the window so it's accessible in the console, and just in general
window.$ = window.jQuery = jQuery;

// required for uppy file upload
import '@uppy/core/dist/style.css'
import '@uppy/dashboard/dist/style.css'
window.Uppy = require('@uppy/core')
window.XHRUpload = require('@uppy/xhr-upload')
window.Dashboard = require('@uppy/dashboard')
window.DragDrop = require('@uppy/drag-drop')
window.Tus = require("@uppy/tus")
window.ProgressBar = require("@uppy/progress-bar")
window.FileInput = require('@uppy/file-input')
window.Form = require("@uppy/form")
