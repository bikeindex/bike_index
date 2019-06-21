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

require('script-loader!blueimp-file-upload/js/vendor/jquery.ui.widget.js');
require('script-loader!blueimp-tmpl/js/tmpl.js');
require('script-loader!blueimp-load-image/js/load-image.all.min.js');
require('script-loader!blueimp-canvas-to-blob/js/canvas-to-blob.js');
require('script-loader!blueimp-file-upload/js/jquery.iframe-transport.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-process.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-image.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-audio.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-video.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-validate.js');
require('script-loader!blueimp-file-upload/js/jquery.fileupload-ui.js');
