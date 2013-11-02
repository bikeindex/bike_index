class BikeIndex.Views.BikesEdit extends Backbone.View
  events:
    'change .with-additional-block select': 'expandAdditionalBlock'
    'click a.optional-form-block': 'optionalFormUpdate'
    'change .standard-diams': 'updateWheelDiam'
    'click #mark-stolen': 'markStolen'
    'click #mark-unstolen': 'markUnstolen'
    'click #edit-menu a': 'scrollToMenuTarget'
    'click .remove_fields': 'removeComponent'
    'click .add_fields': 'addComponent'
    'change .part-type-select select': 'updatePartType'
    'change .component_model input': 'toggleExtraModelField'
    'change .drive-check': 'toggleDrivetrainChecks'
    'change #edit_drivetrain select': 'updateDrivetrainValue'
    'click #frame-sizer button': 'updateFrameSize'
    
  initialize: ->
    @setElement($('#body'))
    menu_height = $('#edit-menu').offset().top 
    scroll_height = $(window).height() * .4
    @setDefaultCountry()
    $('#body').attr('data-spy', "scroll").attr('data-target', '#edit-menu')
    $('#body').scrollspy(offset: - scroll_height)
    $('#clearing_span').css('height', $('#edit-menu').height() + 25)
    $('#edit-menu').attr('data-spy', 'affix').attr('data-offset-top', (menu_height-25))
    # $('#edit-menu').attr('data-spy', 'affix').attr('data-offset-top', 10)
    # $('#edit-menu').affix()
    @setInitialValues()

    if $('#new_public_image').length > 0
      # we need to rename the damn field or it breaks
      $('#public_image_image').attr('name', "public_image[image]")
      @publicImageFileUpload()

    if $('#public_images').length > 0
      @sortableImages($('#public_images'))


  scrollToMenuTarget: (event) ->
    event.preventDefault()
    target = $(event.target).attr('href')
    $('body').animate( 
      scrollTop: ($(target).offset().top - 20), 'fast' 
    )

  publicImageFileUpload: ->
    runSortableImages = @sortableImages($('#public_images'))
    $('#new_public_image').fileupload
      dataType: "script"
      add: (e, data) ->
        types = /(\.|\/)(gif|jpe?g|png)$/i
        file = data.files[0]
        $('#public_images').sortable('disable')
        if types.test(file.type) || types.test(file.name)
          data.context = $('<div class="upload"><p><em>' + file.name + '</em></p><div class="progress progress-striped active"><div class="bar" style="width: 0%"></div></div></div>')
          $('#new_public_image').append(data.context)
          data.submit()
        else
          alert("#{file.name} is not a gif, jpeg, or png image file")
      progress: (e, data) ->
        if data.context
          progress = parseInt(data.loaded / data.total * 95, 10) # Multiply by 95, so that it doesn't look done, since progress doesn't work.
          data.context.find('.bar').css('width', progress + '%')
      done: (e, data) ->
        runSortableImages
        file = data.files[0]
        $.each(data.files, (index, file) ->
          data.context.addClass('finished_upload').html("""
              <p><em>#{file.name}</em></p>
              <div class='alert-success'>
                Finished uploading
              </div>
            """).fadeOut('slow')
          )

  sortableImages:(sortable_container) ->
    # run this as soon as the function starts to update any recently uploaded images
    @pushImageOrder(sortable_container)
    sortable_container.sortable().bind 'sortupdate', (e, ui) =>
      # And obviously run it on update too
      @pushImageOrder(sortable_container)

  pushImageOrder: ( sortable_container ) ->
    urlTarget = sortable_container.data('order-url')
    sortable_list_items = sortable_container.children('li')
    # This is a list comprehension for the list of all the sortable items, to make an array
    array_of_photo_ids = ($(list_item).attr('id') for list_item in sortable_list_items)
    new_item_order = 
      list_of_photos: array_of_photo_ids
    # list_of_items is an array containing the ordered list of image_ids
    # Then we post the result of the list comprehension to the url to update
    $.post(urlTarget, new_item_order)


  setInitialValues: ->
    if $('#stolen_date').length > 0
      $('#stolen_date input').datepicker('format: mm-dd-yyy')
    @setWheelDiam('front')
    @setWheelDiam('rear')
    @showColors()
    @expandAdditionalBlockFromSelector('#bike_handlebar_type_id')
    @expandAdditionalBlockFromSelector('#bike_frame_material_id')
    @expandAdditionalBlockFromSelector('#bike_frame_material_id')
    @expandAdditionalBlockFromSelector('.component-mnfg-select select')
    @expandAdditionalBlockFromSelector('.part-type-select select')
    @setInitialGears()
    @setFrameSize()


  expandAdditionalBlock: (event) ->
    target = $(event.target)
    group = target.parents('.input-group')
    current_value = target.parents('.control-group').find('select').val()
    if group.hasClass('add-component-fields')
      expand_value = target.parents('.control-group').attr('data-other')
      other = target.parents('.control-group').attr('data-hidden')
      hidden_other = target.parents('article').find(other)
    else
      expand_value = group.find('.other-value').text()    
      hidden_other = group.find('.hidden-other')
    @expandIfMatches(hidden_other, current_value, expand_value)


  expandAdditionalBlockFromSelector: (selector) ->
    selector = $(selector)
    group = selector.parents('.input-group')
    current_value = selector.parents('.control-group').find('select').val()
    if group.hasClass('add-component-fields')
      expand_value = selector.parents('.control-group').attr('data-other')
      other = selector.parents('.control-group').attr('data-hidden')
      hidden_other = selector.parents('article').find(other)
    else
      expand_value = group.find('.other-value').text()    
      hidden_other = group.find('.hidden-other')
    @expandIfMatches(hidden_other, current_value, expand_value)


  expandIfMatches: (hidden_other, current_value, expand_value) ->
    if parseInt(current_value, 10) == parseInt(expand_value, 10)
      # show the bugger!
      hidden_other.slideDown().addClass('unhidden')
    else 
      # if it's visible, clear it and slide up
      if hidden_other.hasClass('unhidden')
        hidden_other.find('input').val('')
        hidden_other.removeClass('unhidden').slideUp()

  optionalFormUpdate: (event) ->
    target = $(event.target)
    clickTarget = $(target.attr('data-target'))
    $(target.attr('data-toggle')).show().removeClass('currently-hidden')
    target.addClass('currently-hidden').hide()
    if target.hasClass('wh_sw')
      @updateWheels(target, clickTarget)
    else
      if target.hasClass('rm-block')
        clickTarget.slideUp().removeClass('unhidden').addClass('currently-hidden')
      else
        clickTarget.slideDown().addClass('unhidden').removeClass('currently-hidden')


  updateWheels: (target, clickTarget) ->
    standard = clickTarget.parents('.controls').find('.standard-diams')
    if target.hasClass('show-all')
      standard.fadeOut('fast', ->
        clickTarget.fadeIn()
      )
    else
      clickTarget.fadeOut('fast', ->
        clickTarget.val('')
        standard.val('')
        standard.fadeIn()
      )
  
  setWheelDiam: (position) ->
    wheelDiam = $("#bike_#{position}_wheel_size_id").val()
    if $("##{position}_standard option[value=#{wheelDiam}]").length
      $("##{position}_standard").val(wheelDiam)
      $("#bike_#{position}_wheel_size_id").hide()
    else
      $("##{position}_standard").hide()
      $("#show-#{position}-wheel-diams").addClass('currently-hidden').hide()
      $("#hide-#{position}-wheel-diams").removeClass('currently-hidden').show()
      
  updateWheelDiam: (event) ->
    target = $(event.target)
    cv = target.val()
    position = 'rear'
    $("#bike_#{position}_wheel_size_id").val(cv) if cv.length > 0

  updateCycleType: ->
    current_value = $("#cycletype#{$("#bike_cycle_type_id").val()}")
    $('#cycletype-text').removeClass('long-title')
    if current_value.hasClass('long-title')
      $('#cycletype-text').addClass('long-title')  
    $('#cycletype-text').text(current_value.text())

  showColors: ->
    if $('#bike_secondary_color_id').val()
      $($('#add-secondary').attr('data-toggle')).show().removeClass('currently-hidden')
      $('#add-secondary').addClass('currently-hidden').hide()
      $($('#add-secondary').attr('data-target')).show().addClass('unhidden')
    if $('bike_tertiary_color_id').val()
      $($('#add-tertiary').attr('data-toggle')).show().removeClass('currently-hidden')
      $('#add-tertiary').addClass('currently-hidden').hide()
      $($('#add-tertiary').attr('data-target')).show().addClass('unhidden')

  markUnstolen: ->
    $('#bike_stolen').prop('checked', '')

  markStolen: ->
    $('#bike_stolen').prop('checked', 'true')

  setDefaultCountry: ->
    c_select = $('#country_select_container select')
    if c_select.length > 0
      us_val = parseInt($('#country_select_container .other-value').text(), 10)
      c_select.val(us_val).select2() unless c_select.val()
      c_select.change ->
        if c_select.val() == us_val
          $('#state-select').slideDown()
        else 
          $('#state-select').slideUp()


  removeComponent: (event) ->
    # We don't need to do anything except slide the input up, because the label is on it.
    target = $(event.target)
    target.prev('input[type=hidden]').val('1')
    target.closest('fieldset').slideUp()

  addComponent: ->
    event.preventDefault()
    target = $('.add_fields')
    time = new Date().getTime()
    regexp = new RegExp(target.attr('data-id'), 'g')
    target.before(target.data('fields').replace(regexp, time))
    $('.chosen-select select').select2()
    # $('.input-group.add-additional .with-additional-block select').on 'change', @expandAdditionalBlock


  updatePartType: (event) ->
    group = $(event.target).parents('.input-group')
    twin_parts = $('#twin_part_types').text().replace(/^(\s*)|(\s*)$/g, '').split(',')
    current_value = group.find('select').val()
    # Check if the part is a twin part
    is_twined = false
    for twin_part in twin_parts
      if twin_part == current_value
        is_twined = true
    # Show or hide it and mark values
    if is_twined
      # if group.find('.front-or-rear-part').hasClass('currently-hidden')
      group.find('.front-or-rear-part input').prop('checked', 'true')
      group.find('.front-or-rear-part').fadeIn('fast')
      # group.find('.front-or-rear-part').removeClass('currently-hidden')
    else
      group.find('.front-or-rear-part input').prop('checked', '')
      group.find('.front-or-rear-part').fadeOut('fast')

  toggleExtraModelField: (event) ->
    target = $(event.target)
    hidden_other = target.parents('.input-group').find('.extra-model-fields')
    if target.val().length > 1    
      # show the bugger!
      hidden_other.slideDown().addClass('unhidden')
    else 
      # if it's visible, clear it and slide up
      if hidden_other.hasClass('unhidden')
        hidden_other.find('input').val('')
        hidden_other.removeClass('unhidden').slideUp()

  setFrameSize: ->
    unit = $('#bike_frame_size_unit').val()
    if unit != 'ordinal' and unit.length > 0
      $('#frame-sizer .hidden-other').slideDown().addClass('unhidden')
      $('#frame-sizer .groupedbtn-group').addClass('ex-size')

  updateFrameSize: ->
    size = $(event.target).attr('data-size')
    hidden_other = $('#frame-sizer .hidden-other')
    if size == 'cm' or size == 'in'
      $('#bike_frame_size_unit').val(size)
      unless hidden_other.hasClass('unhidden')
        hidden_other.slideDown('fast').addClass('unhidden')
        $('#bike_frame_size').val('')
        $('#frame-sizer .groupedbtn-group').addClass('ex-size')
    else
      $('#bike_frame_size_unit').val('ordinal')
      $('#bike_frame_size').val(size)
      if hidden_other.hasClass('unhidden')
        hidden_other.removeClass('unhidden').slideUp('fast')
        $('#frame-sizer .groupedbtn-group').removeClass('ex-size')
      
  toggleDrivetrainChecks: (event) ->
    target = $(event.target)
    id = target.attr('id')
    if id == 'fixed_gear_check'
      if target.prop('checked') == true
        @setFixed()
      else
        $('.not-fixed').slideDown()
        @setDrivetrainDisplay(['front','rear'], 'standard')

    else
      if id == 'front_internal_check'
        if target.prop('checked') == true
          @setDrivetrainDisplay(['front'],'internal')
        else 
          @setDrivetrainDisplay(['front'],'standard')
      if id == 'rear_internal_check'
        if target.prop('checked') == true
          @setDrivetrainDisplay(['rear'],'internal')
        else 
          @setDrivetrainDisplay(['rear'],'standard')
      
      if id == 'bike_coaster_brake'
        if target.prop('checked') == true
          $('#rear_internal_check').prop('checked', true)
          @setDrivetrainDisplay(['rear'],'internal')
        else 
          @setDrivetrainDisplay(['rear'],'standard')

  setFixed: ->
    $('.not-fixed').slideUp('medium')
    $('#rear_internal_check, #front_internal_check').prop('checked', '')  
    @setDrivetrainDisplay(['front','rear'], 'fixed')

  setDrivetrainDisplay: (positions, type) ->
    for position in positions
      $("##{position}-gear-select .select-display").html($("##{position}-#{type}").html())
    @updateDrivetrainValue()
  
  updateDrivetrainValue:  ->
    $('#bike_front_gear_type_id').val($('#front-gear-select .select-display').val())
    $('#bike_rear_gear_type_id').val($('#rear-gear-select .select-display').val())

  setInitialGears: ->
    if $('#fixed_gear_check').prop('checked') == true
      @setFixed()
    else
      front = $('#bike_front_gear_type_id').val()
      rear = $('#bike_rear_gear_type_id').val()
      @setDrivetrainDisplay(['front','rear'],'standard')
      if $('#front_internal_check').prop('checked') == true
        @setDrivetrainDisplay(['front'],'internal')
      if $('#rear_internal_check').prop('checked') == true
        @setDrivetrainDisplay(['rear'],'internal')
      $('#rear-gear-select .select-display').val(rear)
      $('#front-gear-select .select-display').val(front)
