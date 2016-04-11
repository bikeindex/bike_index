class BikeIndex.BikesEditWheelsDrivetrain extends BikeIndex
  constructor: ->
    @initializeEventListeners()
    @initializeWheelDiams(side) for side in ['front', 'rear']
    @setInitialGears()

  initializeEventListeners: ->
    pagespace = @
    $('.standard-diams select').change (e) ->
      pagespace.updateDiamsFromStandardChange(e)
    $('.drive-check').change (e) ->
      pagespace.toggleDrivetrainChecks(e)
    $('#edit_drivetrain select').change (e) ->
      pagespace.updateDrivetrainValue(e)
    # 'change .drive-check': 'toggleDrivetrainChecks'
    # 'change #edit_drivetrain select': 'updateDrivetrainValue'

  # 
  # Wheels
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


  # 
  # Drivetrain
  toggleDrivetrainChecks: (e) ->
    $target = $(e.target)
    id = $target.attr('id')
    if id == 'fixed_gear_check'
      @toggleFixed($target.prop('checked'))
    else
      if id == 'front_gear_select_internal'
        @setDrivetrainValue('front_gear_select')
      if id == 'rear_gear_select_internal'
        @setDrivetrainValue('rear_gear_select')
        
  toggleFixed: (is_fixed) ->
    fixed_values = {}
    for side in ['front', 'rear']
      # Remove the select gear value
      selectize = $("##{side}_gear_select").selectize()[0]
      selectize.selectize.setValue('')
      # Set the fixed values
      fixed_values[side] = $("##{side}_gear_select_value").attr('data-fixed')
    if is_fixed
      $('#edit_drivetrain .not-fixed').slideUp 'medium', ->
        $('#edit_drivetrain .not-fixed input[type="checkbox"]').prop('checked', '')
        $("#front_gear_select_value #bike_front_gear_type_id_#{fixed_values.front}").prop('checked', true)
        $("#rear_gear_select_value #bike_rear_gear_type_id_#{fixed_values.rear}").prop('checked', true)
    else
      $('#front_gear_select_value .no-gear-selected, #rear_gear_select_value .no-gear-selected').prop('checked', true)
      $('.not-fixed').slideDown()


  setDrivetrainValue: (position) ->
    v = parseInt($("##{position}").val(), 10)
    i = $("##{position}_internal").prop('checked')
    if isNaN(v)
      $("##{position}_value .placeholder").prop('selected', 'selected')
    else
      $("##{position}_value .count_#{v}.internal_#{i}").prop('checked', true)
      if v == 0
        $('#rear_gear_select_internal').prop('checked', true)

  updateDrivetrainValue: (event) ->
    if $('#fixed_gear_check').prop('checked')
      return true
    else
      position = $(event.target).attr('id')
      @setDrivetrainValue(position)
    
  setInitialGears: ->
    if $('#fixed_gear_check').prop('checked') == true
      @toggleFixed(true)
    else
      for side in ['front', 'rear']
        count = $("##{side}_gear_select_value").attr('data-initialcount')
        console.log side, count
        unless isNaN(count)
          selectize = $("##{side}_gear_select").selectize()[0]
          selectize.selectize.setValue(count)

      # if isNaN(rear_count)
      #   $('#rear_gear_select .placeholder').prop('selected', 'selected')
      # else
      #   $('#rear_gear_select').val(rear_count)