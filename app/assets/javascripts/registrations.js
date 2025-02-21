// require self
//= require external_scripts/registrations_dependencies.js
//= require external_scripts/bootstrap
//= require external_scripts/selectize_placeholder_plugin.js
//= require revised/components/check_email.js
//= require revised/components/manufacturers_select.js
//= require revised/components/update_propulsion_type.js

$(document).ready(function() {
  // Load the fancy selects
  $('.unfancy.fancy-select select').selectize({
    create: false,
    plugins: ['restore_on_backspace']
  });
  // Load the manufacturers select
  new window.ManufacturersSelect('#binx_registration_widget #b_param_manufacturer_id');
  new window.CheckEmail('#b_param_owner_email');
  new window.UpdatePropulsionType('b_param');
});
