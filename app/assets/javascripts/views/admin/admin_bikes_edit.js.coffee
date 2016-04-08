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
    initial_opts = []
    $target = $(target)
    per_page = 10
    frame_mnfg_url = "#{window.root_url}/api/autocomplete?per_page=#{per_page}&categories=frame_mnfg&q="
    $target.selectize
      plugins: ['restore_on_backspace']
      options: [$target.data('initial')]
      preload: false
      persist: false
      create: false
      maxItems: 1
      valueField: 'id'
      labelField: 'text'
      searchField: 'text'
      loadThrottle: 150
      score: (search) ->
        score = this.getScoreFunction(search)
        return (item) ->
          score(item) * (1 + Math.min(item.priority / 100, 1))
      load: (query, callback) ->
        $.ajax
          url: "#{frame_mnfg_url}#{encodeURIComponent(query)}"
          type: 'GET'
          error: ->
            callback()
          success: (res) ->
            callback res.matches.slice(0, per_page)

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