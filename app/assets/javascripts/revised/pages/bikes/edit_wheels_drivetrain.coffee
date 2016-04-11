class BikeIndex.BikesEditWheelsDrivetrain extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    @initializeWheelDiams(side) for side in ['front', 'rear']

  initializeEventListeners: ->
    pagespace = @
    $('.standard-diams select').change (e) ->
      pagespace.updateDiamsFromStandardChange(e)

  updateDiamsFromStandardChange: (e) ->
    current_val = e.target.value
    $target = $(e.target).parents('.form-well-input').find('.all-diams select')
    selectize = $target.selectize()[0].selectize
    selectize.setValue(current_val)

  initializeWheelDiams: (side) ->
    current_val = $("##{side}_all select").val()
    $standard_diams = $("##{side}_standard select")

    if current_val.length > 0
      # Seems like you can't do normal options mapping because selectize,
      # so we have to do it through selectize
      selectize = $standard_diams.selectize()[0].selectize
      standard_values = Object.keys(selectize.options)
      if current_val in standard_values
        selectize.setValue(current_val)
      else
        $all_diams_btn = $standard_diams.parents('.related-fields').find('.show-all-diams')
        $all_diams_btn.trigger('click', false)