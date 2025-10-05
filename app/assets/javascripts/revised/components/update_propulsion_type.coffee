class @UpdatePropulsionType
  # model_name can be 'bike' or 'b_param'
  constructor: (model_name) ->
    @updateTypes(model_name)
    $("##{model_name}_cycle_type").change (e) =>
      @updateTypes(model_name)
    $('#propulsion_type_motorized').change (e) =>
      @updateTypes(model_name)
    $('.modal').on 'show.bs.modal', =>
      # Need to trigger correct text on modal
      @updateTypes(model_name)

  # Set motorized if it should be motorized.
  # Only show propulsion type options if there can be options
  # embed_script.js.coffee has a simpler version of this method
  updateTypes: (model_name) ->
    cycleTypeValue = $("##{model_name}_cycle_type").val()
    if window.cycleTypesAlwaysMotorized.includes(cycleTypeValue)
      $('#propulsionTypeFields').collapse('hide')
      $('#propulsion_type_motorized').prop('checked', true)
      $('#propulsion_type_motorized').attr('disabled', true)
      $('#motorizedWrapper').addClass('less-strong cursor-not-allowed').removeClass('cursor-pointer')
    else if window.cycleTypesNeverMotorized.includes(cycleTypeValue)
      $('#propulsion_type_motorized').prop('checked', false)
      $('#propulsion_type_motorized').attr('disabled', true)
      $('#propulsionTypeFields').collapse('hide')
      $('#motorizedWrapper').addClass('less-strong cursor-not-allowed').removeClass('cursor-pointer')
    else
      $('#motorizedWrapper').addClass('cursor-pointer').removeClass('less-strong cursor-not-allowed')
      $('#propulsion_type_motorized').attr('disabled', false)
      if $('#propulsion_type_motorized').prop('checked')
        if window.cycleTypesPedals.includes(cycleTypeValue)
          $('#propulsionTypeFields').collapse('show')
        else
          $('#propulsionTypeFields').collapse('hide')
      else
        $('#propulsionTypeFields').collapse('hide')

        $('#propulsion_type_throttle').prop('checked', false)
        $('#propulsion_type_pedal_assist').prop('checked', false)

    if window.cycleTypeTranslations
      # Update cycle_type text on the page (if there is a )
      newTypeText = window.cycleTypeTranslations[cycleTypeValue]
      if newTypeText.length
        $(".cycleTypeText").text(newTypeText)
      if window.cycleTypesNot.includes(cycleTypeValue)
        $(".cycleTypeOnly").collapse("hide")
        $(".notCycleTypeOnly").collapse("show")
      else
        $(".cycleTypeOnly").collapse("show")
        $(".notCycleTypeOnly").collapse("hide")
