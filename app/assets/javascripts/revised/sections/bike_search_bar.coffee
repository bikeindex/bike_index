class BikeIndex.BikeSearchBar extends BikeIndex
  constructor: (target_selector = '#bikes_search_form #query_items') ->
    @initializeHeaderSearch($(target_selector))
    @setSearchProximity()
    @initializeEventListeners()

  initializeEventListeners: ->
    $('#stolen_proximity_tab').click (e) =>
      @proximitySearch(e)
    $('#stolen_tab').click (e) =>
      @stolenSearch(e)
    $('#non_stolen_tab').click (e) =>
      @nonStolenSearch(e)
    
  setSearchProximity: ->
    proximity = $('#proximity').val()
    proximity = if proximity? then proximity.replace(/^\s*|\s*$/g, '') else ''
    # If there is a search_location, it means this was an IP search and we need to set proximity
    if Array.isArray(window.search_location_geocoding) && window.search_location_geocoding[0]?
      location_data = window.search_location_geocoding[0].data
      # Maxmind (what we use in production for ip lookup) formats results differently than google
      # This doesn't work in dev... but it wouldn't work anyway because localhost
      if Array.isArray(location_data)
        proximity = "#{location_data[2]}, #{location_data[1]}"
        # Set the text box
        $('#proximity').val(proximity)
    # Store proximity in localStorage if it's there, otherwise -
    # Set from localStorage - so we don't override if it's already set
    # updateSearchBikesHeaderLink is called first, this is guaranteed to be something
    if proximity? and proximity.length > 0
      # don't save location if user entered set 'Anywhere'
      localStorage.setItem('location', proximity) unless proximity.match(/anywhere/i)
    else
      proximity = localStorage.getItem('location')
      # Make location 'you' if location is anywhere, so user isn't stuck unable to use proximity
      proximity = 'you' if proximity.match(/anywhere/i)
      # Then set the proximity from whatever we got
      $('#proximity').val(proximity)
    # set up search view if we're on bike search
    @setSearchTabInfo(proximity)
    # Set the header link
    window.updateSearchBikesHeaderLink()

  setSearchTabInfo: (proximity) ->
    $('#search_distance').text($('#proximity_radius').val())
    $('#search_location').text(proximity)
    query = $('.search-type-tabs').attr('data-query')
    $.ajax
      type: 'GET'
      url: "/api/v2/bikes_search/count?#{query}"
      # url: "<%= ENV['BASE_URL'] %>/api/v2/bikes_search/count?#{query}"
      success: (data) =>
        @insertTabCounts(data)

  displayedCountNumber: (number) ->
    if number > 999
      if number > 9999
        number = '10k+'
      else
        number = "#{String(number).charAt(0)}k+"
    "(#{number})"

  insertTabCounts: (counts) ->
    displayedCountNumber = @displayedCountNumber
    $('#stolen_tab .count').text(displayedCountNumber(counts.stolen))
    $('#stolen_proximity_tab .count').text(displayedCountNumber(counts.proximity))
    $('#non_stolen_tab .count').text(displayedCountNumber(counts.non_stolen))

  stolenSearch: (e) ->
    e.preventDefault()
    $('#stolen').val('true')
    $('#non_stolen').val('')
    $('#non_proximity').val('true')
    $('#bikes_search_form').submit()

  nonStolenSearch: (e) ->
    e.preventDefault()
    $('#stolen').val('')
    $('#non_stolen').val('true')
    $('#bikes_search_form').submit()

  proximitySearch: (e) ->
    e.preventDefault()
    $('#stolen').val('true')
    $('#non_stolen').val('')
    $('#non_proximity').val('')
    $('#bikes_search_form').submit()

  updateIncludeSerialOption: ($query_field) ->
    # Check if the header search includes the serial string match, set it on the window
    query_val = $query_field.val()
    window.includeSerialOption = !(query_val.match(/s(#|%23)[^(#|%23)]*(#|%23)/))

  initializeHeaderSearch: ($query_field) ->
    per_page = 15
    initial_opts = if $query_field.data('initial') then $query_field.data('initial') else []
    formatSearchText = @formatSearchText # custom formatter
    $desc_search = $query_field.select2
      allowClear: true
      tags: true
      multiple: true
      openOnEnter: false
      tokenSeparators: [',']
      placeholder: $query_field.attr('placeholder') # Pull placeholder from HTML
      dropdownParent: $('.bikes-search-form') # Append to search for for easier css access
      templateResult: formatSearchText # let custom formatter work
      escapeMarkup: (markup) -> markup # Allow our
      ajax:
        url: '/api/autocomplete'
        dataType: 'json'
        delay: 150
        data: (params) ->
          q: params.term
          page: params.page
          per_page: per_page
        processResults: (data, page) ->
          results: _.map(data.matches, (item) ->
            id: item.search_id
            text: item.text
            category: item.category
            display: item.display
          )
          pagination:
            # If exactly per_page matches there's likely at another page
            more: data.matches.length == per_page
        cache: true

    # Submit on enter. Requires select2 be appended to bike-search form (as it is)
    # window.bike_search_submit = true
    $('.bikes-search-form .select2-selection').on 'keyup', (e) ->
      # Only trigger submit on enter if:
      #  - Enter key pressed last (13) 
      #  - Escape key pressed last (27)
      #  - no keys have been pressed (selected with the mouse, instantiated true)
      return window.bike_search_submit = true if e.keyCode == 27
      return window.bike_search_submit = false unless e.keyCode == 13
      if window.bike_search_submit
        $desc_search.select2('close') # Because form is submitted, hide select box
        $('#bikes_search_form').submit()
      else
        window.bike_search_submit = true

  formatSearchText: (item) ->
    return item.text if item.loading
    prefix = switch
      when item.category == 'colors'
        p = "<span class=\'sch_\'>Bikes that are </span>"
        if item.display
          p + "<span class=\'sclr\' style=\'background: #{item.display};\'></span>"
        else
          p + "<span class=\'sclr\'>stckrs</span>"
      when item.category == 'mnfg' || item.category == 'frame_mnfg'
        "<span class=\'sch_\'>Bikes made by</span>"
      else
        'Search for'
    "#{prefix} <span class=\'label\'>" + item.text + '</span>'