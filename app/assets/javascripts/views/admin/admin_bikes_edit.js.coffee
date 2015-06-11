class BikeIndex.Views.AdminBikesEdit extends Backbone.View
  events:
    'click #frame-sizer button': 'updateFrameSize'
    'keyup': 'submitOnControlEnter'
    
  initialize: ->
    window.root_url = $('#bike_edit_root_url').attr('data-url')
    @setElement($('#body'))
    @initializeFrameMaker("#bike_manufacturer_id")
    if $('#bike_stolen').prop('checked')
      $('#bike_stolen').change ->
        $('#admin-recovery-fields').slideToggle 'medium', ->
          if $('#recovery_descr textarea').attr('required')
            $('#recovery_descr textarea').attr('required', false)
          else
            $('#recovery_descr textarea').attr('required', true)
    if $('.fast-attr-update').length > 0
      $('#bike_cycle_type_id').focus()
      @setFrameSize()
    
  initializeFrameMaker: (target) ->
    url = "#{window.root_url}/api/searcher?types[]=frame_makers&"
    $(target).select2
      minimumInputLength: 2
      placeholder: 'Choose manufacturer'
      ajax:
        url: url
        dataType: "json"
        openOnEnter: true
        data: (term, page) ->
          term: term # search term
          limit: 10
        results: (data, page) -> # parse the results into the format expected by Select2.
          remapped = data.results.frame_makers.map (i) -> {id: i.id, text: i.term}
          results: remapped
      initSelection: (element, callback) ->
        id = $(element).val()
        if id isnt ""
          $.ajax("#{window.root_url}/api/v1/manufacturers/#{id}",
          ).done (data) ->
            data =
              id: element.val()
              text: data.manufacturer.name
            callback data

  setFrameSize: ->
    unit = $('#bike_frame_size_unit').val()
    if unit != 'ordinal' and unit.length > 0
      $('#frame-sizer .hidden-other').slideDown().addClass('unhidden')
      $('#frame-sizer .groupedbtn-group').addClass('ex-size')

  updateFrameSize: (event) ->
    size = $(event.target).attr('data-size')
    hidden_other = $('#frame-sizer .hidden-other')
    if size == 'cm' or size == 'in'
      $('#bike_frame_size_unit').val(size)
      unless hidden_other.hasClass('unhidden')
        hidden_other.slideDown('fast').addClass('unhidden')
        $('#bike_frame_size').val('')
        $('#bike_frame_size_number').val('')
        $('#frame-sizer .groupedbtn-group').addClass('ex-size')
    else
      $('#bike_frame_size_unit').val('ordinal')
      $('#bike_frame_size_number').val('')
      $('#bike_frame_size').val(size)
      if hidden_other.hasClass('unhidden')
        hidden_other.removeClass('unhidden').slideUp('fast')
        $('#frame-sizer .groupedbtn-group').removeClass('ex-size')

  submitOnControlEnter:(event) ->
    if event.keyCode == 13 && event.ctrlKey
      $('.admin-bike-edit').submit()