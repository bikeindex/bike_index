class BikeIndex.Views.BikesNew extends Backbone.View
  events:
    'change #bike_has_no_serial':     'updateSerial'
    'click a.optional-form-block':    'optionalFormUpdate'
    'change #bike_year':              'updateYear'
    'change #bike_unknown_year':      'toggleUnknownYear' 
    'click #select-cycletype a':      'changeCycleType'
    'change #bike_manufacturer_id':   'onManufacturerChange'
    'change #country_select_container select': 'updateCountry'
    
  
  initialize: ->
    @setElement($('#body'))
    if $('#bike_has_no_serial').prop('checked') == true
      $('#bike_serial_number').val('absent').addClass('absent-serial')
    if $('#country_select_container').length > 0
      if $('#country_select_container select').val().length > 0
        @updateCountry()
      else
        @setDefaultCountry()
    @updateCycleType()
    window.root_url = $('#root_url').attr('data-url')
    
    @initializeFrameMaker("#bike_manufacturer_id")
    @otherManufacturerDisplay($("#bike_manufacturer_id").val())
  

  updateSerial: (event) ->
    if $(event.target).prop('checked') == true
      $('#bike_serial_number').val('absent').addClass('absent-serial')
    else
      $('#bike_serial_number').val('').removeClass('absent-serial')


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
        clickTarget.find('select').selectize()[0].selectize.setValue('')
      else
        clickTarget.slideDown().addClass('unhidden').removeClass('currently-hidden')

  updateCycleType: ->
    current_value = $("#cycletype#{$("#bike_cycle_type_id").val()}")
    $('#cycletype-text').removeClass('long-title')
    if current_value.hasClass('long-title')
      $('#cycletype-text').addClass('long-title')  
    $('#cycletype-text').text(current_value.text())


  changeCycleType: (event) ->
    target = $(event.target)
    $('#bike_cycle_type_id').val(target.attr("data-id"))
    @updateCycleType()

  setModelTypeahead: (data=[]) ->
    $('#bike_frame_model').selectize()[0].selectize.destroy()
    if data.length > 0
      window.m_data = data.map (i) -> { id: i }
      $('#bike_frame_model').selectize
        plugins: ['restore_on_backspace']
        options: data.map (i) -> { 'name': i }
        create: true
        maxItems: 1
        valueField: 'name'
        labelField: 'name'
        searchField: 'name'

  getModelList: (mnfg_name) ->
    if mnfg_name == 'absent'
      @setModelTypeahead()
    else
      year = parseInt($('#bike_year').val(),10)
      # could be bikebook.io - but then we'd have to pay for SSL...
      url = "https://bikebook.herokuapp.com/model_list/?manufacturer=#{mnfg_name}"
      url += "&year=#{year}" if year > 1
      that = @
      $.ajax
        type: "GET"
        url: url
        success: (data, textStatus, jqXHR) ->
          that.setModelTypeahead(data)
        error: ->
          that.setModelTypeahead()

  toggleUnknownYear: ->
    year_select = $('#bike_year').selectize()[0].selectize
    if $('#bike_unknown_year').prop('checked')
      year_select.setValue('')
      year_select.disable()
    else
      year_select.setValue(new Date().getFullYear())
      year_select.enable()
  
  updateYear: ->
    if $('#bike_year').val()
      if $('#bike_year').val().length == 0
        $('#bike_year').selectize()[0].selectize.disable()
        $('#bike_unknown_year').prop('checked', true)
      else
        $('#bike_unknown_year').prop('checked', false)

    slug = $('#bike_manufacturer_id').val()
    if slug.length > 0
      @getModelList(slug)
    else
      @getModelList()

  onManufacturerChange: ->
    slug = $('#bike_manufacturer_id').val()
    @otherManufacturerDisplay(slug)
    @getModelList(slug)

  otherManufacturerDisplay: (current_value) ->
    expand_value = 'other'
    hidden_other = $('#bike_manufacturer_id').parents('.input-group').find('.hidden-other')
    if current_value == expand_value
      # show the bugger!
      hidden_other.slideDown().addClass('unhidden')
    else 
      # if it's visible, clear it and slide up
      if hidden_other.hasClass('unhidden')
        hidden_other.find('input').val('')
        hidden_other.removeClass('unhidden').slideUp()
    
  setDefaultCountry: ->
    # we should geocode the country in here if possible...
    default_country_id = parseInt($('#us_country_id').text(), 10)
    $('#country_select_container select').selectize()[0].selectize.setValue(default_country_id)
    
  updateCountry: ->
    c_select = $('#country_select_container select')
    us_val = parseInt($('#country_select_container .other-value').text(), 10)
    if parseInt(c_select.val(), 10) == us_val
      $('#state-select').slideDown()
    else
      $('#state-select').slideUp()
      $('#state-select select').selectize()[0].selectize.setValue('')

  initializeFrameMaker: (target) ->
    per_page = 10
    frame_mnfg_url = "#{window.root_url}/api/autocomplete?per_page=#{per_page}&categories=frame_mnfg&q="
    $(target).selectize
      plugins: ['restore_on_backspace']
      preload: true
      persist: false
      create: false
      maxItems: 1
      valueField: 'slug'
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

