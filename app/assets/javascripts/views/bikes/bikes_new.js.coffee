class BikeIndex.Views.BikesNew extends Backbone.View
  events:
    'change #bike_has_no_serial':     'updateSerial'
    'click a.optional-form-block':    'optionalFormUpdate'
    'change #bike_year':              'updateYear'
    'change #bike_unknown_year':      'toggleUnknownYear' 
    'click #select-cycletype a':      'changeCycleType'
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
    autocomplete = $('#bike_frame_model').typeahead()
    autocomplete.data('typeahead').source = data 
    # $('#bike_frame_model').typeahead({source: data})

  getModelList: (mnfg_name) ->
    year = parseInt($('#bike_year').val(),10)
    # could be bikebook.io - but then we'd have to pay for SSL...
    url = "https://bikebook.herokuapp.com//model_list/?manufacturer=#{mnfg_name}"
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
    if $('#bike_unknown_year').prop('checked')
      $('#bike_year').val('').trigger('change')
      $('#bike_year').select2 "enable", false
    else
      $('#bike_year').val(new Date().getFullYear()).trigger('change')
      $('#bike_year').select2 "enable", true
  
  updateYear: ->
    if $('#bike_year').val().length == 0
      $('#bike_year').select2 "enable", false
      $('#bike_unknown_year').prop('checked', true)
    else
      $('#bike_unknown_year').prop('checked', false)
    id = $('#bike_manufacturer_id').val()
    if id.length > 0
      that = this
      $.ajax("#{window.root_url}/api/v1/manufacturers/#{id}",
      ).done (data) ->
        that.getModelList(data.manufacturer.name)

  otherManufacturerDisplay: (current_value) ->
    expand_value = $('#bike_manufacturer_id').parents('.input-group').find('.other-value').text()
    hidden_other = $('#bike_manufacturer_id').parents('.input-group').find('.hidden-other')
    if parseInt(current_value, 10) == parseInt(expand_value, 10)
      # show the bugger!
      hidden_other.slideDown().addClass('unhidden')
    else 
      # if it's visible, clear it and slide up
      if hidden_other.hasClass('unhidden')
        hidden_other.find('input').val('')
        hidden_other.removeClass('unhidden').slideUp()
    
  setDefaultCountry: ->
    $.getJSON "http://www.telize.com/geoip?callback=?", (json) ->
      select = $('#country_select_container select')
      country_id = select.find("option").filter(->
        $(this).text() is json.country
      ).val()
      select.val(country_id).change()

  updateCountry: ->
    c_select = $('#country_select_container select')
    c_select.select2()
    us_val = parseInt($('#country_select_container .other-value').text(), 10)
    if parseInt(c_select.val(), 10) == us_val
      $('#state-select').slideDown()
    else
      $('#state-select').slideUp()
      $('#state-select select').val('').change()

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
    that = @
    $(target).on "change", (e) ->
      id = e.val
      that.otherManufacturerDisplay(id)
      $.ajax("#{window.root_url}/api/v1/manufacturers/#{id}",
      ).done (data) ->
        that.getModelList(data.manufacturer.name)
