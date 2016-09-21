class BikeIndex.BikeSearchBar extends BikeIndex
  constructor: (target_selector = '#bikes_search_form #query_items') ->
    @initializeHeaderSearch($(target_selector))
    @setSearchProximity()
    @initializeEventListeners()

  initializeEventListeners: ->
    $('#stolenness_tabs a').click (e) =>
      tab = $(event.target).parents('li')
      console.log tab.attr('data-stolenness')
      $('#stolenness').val(tab.attr('data-stolenness'))
      $('#bikes_search_form').submit()

  setSearchProximity: ->
    location = $('#location').val()
    location = if location? then location.replace(/^\s*|\s*$/g, '') else ''
    # If there is a search_location, it means this was an IP search and we need to set location
    if window.interpreted_params.location && Array.isArray(window.interpreted_params.location) && window.interpreted_params.location[0]?
      location_data = window.interpreted_params.location[0].data
      # Maxmind (what we use in production for ip lookup) formats results differently than google
      # This doesn't work in dev... but it wouldn't work anyway because localhost
      if Array.isArray(location_data)
        location = "#{location_data[2]}, #{location_data[1]}"
        # Set the text box
        $('#location').val(location)
    # Store location in localStorage if it's there, otherwise -
    # Set from localStorage - so we don't override if it's already set
    # updateSearchBikesHeaderLink is called first, this is guaranteed to be something
    if location? and location.length > 0
      # Don't save location if user entered 'Anywhere'
      localStorage.setItem('location', location) unless location.match(/anywhere/i)
    else
      location = localStorage.getItem('location')
      # Make location 'you' if location is anywhere, so user isn't stuck and unable to use location
      location = 'you' if location.match(/anywhere/i)
      # Then set the location from whatever we got
      $('#location').val(location)
    # Then set up search view and the top menu link
    @setSearchTabInfo(location)
    window.updateSearchBikesHeaderLink()

  setSearchTabInfo: (location) ->
    $('#search_distance').text($('#distance').val())
    $('#search_location').text(location)
    query = $('.search-type-tabs').attr('data-query')
    $.ajax
      type: 'GET'
      url: "/api/v3/search/count?#{query}"
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
    for stolenness in Object.keys(counts)
      count = @displayedCountNumber(counts[stolenness])
      $("#stolenness_tab_#{stolenness} .count").text(count)

  initializeHeaderSearch: ($query_field) ->
    per_page = 15
    initial_opts = if $query_field.data('initial') then $query_field.data('initial') else []
    processedResults = @processedResults # Custom data processor
    formatSearchText = @formatSearchText # Custom formatter
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
          results: processedResults(data.matches)
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

  processedResults: (items) ->
    _.map(items, (item) ->
      return { id: item, text: item } if typeof item is 'string'
      id: item.search_id
      text: item.text
      category: item.category
      display: item.display
    )

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