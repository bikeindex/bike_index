# Runs on the following templates:
# bikes/edit_report_stolen
# bikes/edit_theft_details


class BikeIndex.BikesEditStolen extends BikeIndex
  constructor: ->
    if $('.stolenEditPage').length > 0
      united_states_id = $('#us_id_data').data('usid')
      new BikeIndex.ToggleHiddenOther('.country-select-input', united_states_id)
