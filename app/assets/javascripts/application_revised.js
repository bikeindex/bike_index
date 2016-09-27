// Using bootstrap 4.0 - it's a gem, so it isn't through rails-assets.
//
// require self
//= require jquery2
//= require jquery_ujs
//= require lodash
//= require tether
//= require bootstrap
//= require jquery.dirtyforms
//= require jquery.dirtyforms/plugins/jquery.dirtyforms.dialogs.bootstrap.min.js
//= require mustache
//= require Stickyfill
//= require select2/select2.full.js
//= require selectize/standalone/selectize.js
//= require external_scripts/selectize_placeholder_plugin.js
//= require external_scripts/headroom
//= require external_scripts/jQuery.headroom
//= require pikaday
//= require mailcheck
//= require external_scripts/zoom.js
//= require dataTables/jquery.dataTables
//= require dataTables/bootstrap/3/jquery.dataTables.bootstrap

// Legacy carousel. Used on homepage. 
// Can use if we need a carousel, though would be nice to use rails-assets version instead 
//= require external_scripts/slick.js

// Things that are required for File Upload:
//= require external_scripts/jquery_sortable_0.9.13.js
//= require external_scripts/jquery.ui.widget.js
//= require external_scripts/jquery.iframe-transport.js
//= require external_scripts/jquery.fileupload.js

// Our actual scripts:
//= require init.coffee
//= require_tree ./revised
