class BikeIndex.Views.StolenMultiSerialSearch extends Backbone.View
  events:
    'click #show_multi_search':       'toggleMultiSearch'
    'change #multi_serial_search':    'unlockSearch'
    'click #search_serials':          'searchForSerials'
    'click #multiserial_fuzzy':       'searchSerialsFuzzy'
    
  initialize: ->
    @setElement($('body'))
    @toggleMultiSearch() if window.location.href.match(/multi.serial.search/i)

  Array::uniq = ->
    output = {}
    output[@[key]] = @[key] for key in [0...@length]
    value for key, value of output

  trim = (str) ->
    str.replace(/^\s\s*/, "").replace /\s\s*$/, ""

  idify = (str) ->
    str.replace(/[^a-z0-9]/g, "_")

  toggleMultiSearch: (e=null) ->
    e.preventDefault() if e?
    $('.multi-search-toggle').fadeOut()
    $('.sbr-banner').after($('#ms_search_section'))
    $('.sbr-banner, .sbr-search-fields').slideUp()
    $('#ms_search_section, #ms_form_section').slideDown()



  unlockSearch: ->
    $('#multiserial_fuzzy, #search_serials').addClass('ms_unlocked')
  
  searchForSerials: (event) ->
    event.preventDefault()
    return true unless $('#search_serials').hasClass('ms_unlocked')
    $('#search_serials').removeClass('ms_unlocked')    
    $('#multiserial_fuzzy').fadeIn()
    $('#bikes_returned, #serials_submitted').empty()
    serials = $('#multi_serial_search').val().split(/,|\n/)
    serials = serials.map (s) -> trim(s)
    serials = serials.uniq()
    for serial in serials
      $('#ms_search_section').slideDown().removeClass('hidden')
      if serial.length > 1
        $('#serials_submitted').append("<li name='#{serial}'>#{serial}</li>")
        @getSerialResponse(serial)

  getSerialResponse: (serial) ->
    base_url = $('#search_serials').attr('data-target')
    that = this
    $.ajax
      type: "GET"
      url: "#{base_url}?serial=#{serial}&multi_serial_search=true"
      success: (data, textStatus, jqXHR) ->
        if data.bikes.length < 1
          s_i = $("#serials_submitted li[name='#{serial}']").addClass('ms-nomatch')
        else
          that.appendBikes(data.bikes, serial)
  
  bikeList: (bikes) ->
    list = ''
    for bike in bikes
      list += "<li>"
        
      list += '<span class="stolen-color">Stolen</span>' if bike.stolen
      list += """
          <a href='#{bike.url}' target='_blank'>#{bike.title}</a>
          <span class='serial-text'>##{encodeURI(bike.serial)}</span>
        </li>
      """
    list

  appendBikes: (bikes, serial, fuzzy=false) ->
    s_i = $("#serials_submitted li[name='#{serial}']")
    s_i.addClass('ms-match').removeClass('ms-nomatch')
    unless s_i.find('a').length > 0
      # make the li a link, add the returned bikes container
      s_i.append("<a href='##{idify(serial)}' class='scroll-to-ref'></a>")
      $('#bikes_returned').append("<div id='#{idify(serial)}' class='multiserial-results'></div>")
    s_i.find('a').addClass('blink-class')
    setTimeout (->
      s_i.find('a').removeClass('blink-class')
    ), 500
    
    results = if (bikes.length > 19) then 'First 20 of many' else bikes.length
    if fuzzy  
      html = "<div class='multiserial-fuzzy-result'><h3>Close to serial "
    else
      html = "<div><h3>"
    html += "<span class='serial-text'>#{serial}</span> - #{results} results</h3>"
    html += "<ul>#{@bikeList(bikes)}</ul></div>"
    $("##{idify(serial)}").append(html)

  searchSerialsFuzzy: (event) ->
    event.preventDefault()
    return true unless $('#multiserial_fuzzy').hasClass('ms_unlocked')
    $('#multiserial_fuzzy').removeClass('ms_unlocked')
    for li in $('#serials_submitted li')
      serial = $(li).attr('name')
      @getFuzzySerialResponse(serial)
    

  getFuzzySerialResponse: (serial) ->
    base_url = $('#multiserial_fuzzy').attr('data-target')
    that = this
    $.ajax
      type: "GET"
      url: "#{base_url}?serial=#{serial}&multi_serial_search=true"
      success: (data, textStatus, jqXHR) ->
        if data.bikes.length > 1
          that.appendBikes(data.bikes, serial, true)
