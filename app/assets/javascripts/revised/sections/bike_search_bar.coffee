class BikeIndex.BikeSearchBar extends BikeIndex
  constructor: (target_selector = '#bikes_search_form #query_items') ->
    @setCategories() # Set the categories for the query
    @initializeHeaderSearch($(target_selector))
    $location = $('#location')
    @setSearchProximity($location) if $location.length > 0
    @initializeEventListeners()

  initializeEventListeners: ->
    # Submit form on clicking one of the stolenness tabs -
    # ... So that if user enters new information then clicks, the new info is applied
    $('#stolenness_tabs a').click (e) =>
      # If there are any modifier keys held, don't try to submit the form
      # The user is probably trying to open up a separate tab or something
      if e.altKey or e.ctrlKey or e.metaKey or e.shiftKey
        return
      tab = $(e.target).parents('li')
      $('#stolenness').val(tab.attr('data-stolenness'))
      $('#bikes_search_form').submit()
      false # return false to prevent following the link

  setSearchProximity: ($location) ->
    location = $location.val()
    location = if location? then location.replace(/^\s*|\s*$/g, '') else ''
    # If there is a search_location, it means this was an IP search and we need to set location
    if window.interpreted_params.location?
      location_data = window.interpreted_params.location
      # Maxmind (what we use in production for ip lookup) formats results differently than google
      # This doesn't work in dev... but it wouldn't work anyway because localhost
      if Array.isArray(location_data)
        location = location_data.join(', ')
        # Set the text box
        $('#location').val(location)
    # Store location in localStorage if it's there, otherwise -
    # Set from localStorage - so we don't override if it's already set
    # updateSearchBikesHeaderLink is called first, this is guaranteed to be something
    if location? and location.length > 0
      # Don't save location if user entered 'Anywhere'
      unless location.match(/anywhere/i)
        localStorage.setItem('location', location)
        localStorage.setItem('distance', $('#distance').val())
    else
      location = localStorage.getItem('location')
      # Make location 'you' if location is anywhere or blank, so user isn't stuck and unable to use location
      location = 'you' if !location? || location.match(/anywhere/i)
      # Then set the location from whatever we got
      $location.val(location)
    # Then set up search view and the top menu link
    @setSearchTabInfo(location)
    window.updateSearchBikesHeaderLink()

  setSearchTabInfo: (location) ->
    $('#search_distance').text($('#distance').val())
    $('#search_location').text(location)
    search_data = _.merge(window.interpreted_params, { location: location })
    $.ajax
      type: 'GET'
      url: '/api/v3/search/count'
      data: search_data
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
    $('.query-field-wrap').removeClass('nojs')
    $('.query-field#query').remove() # remove it so it doesn't interfere with query_items
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
      # selectOnClose: true # Turned off in PR#2325
      escapeMarkup: (markup) -> markup # Allow our fancy display of options
      ajax:
        url: '/api/autocomplete'
        dataType: 'json'
        delay: 150
        data: (params) ->
          q: params.term
          page: params.page
          per_page: per_page
          categories: window.searchBarCategories
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

    # Every time the select changes, check the categories
    $query_field.on 'change', (e) =>
      @setCategories()

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
    return "<span>Search only for <strong>#{ item.text }</strong></span>" if item.category == 'cycle_type'
    prefix = switch
      when item.category == 'colors'
        p = "<span class=\'sch_\'>Bikes that are </span>"
        if item.display
          p + "<span class=\'sclr\' style=\'background: #{item.display};\'></span>"
        else
          p + "<span class=\'sclr\'>stckrs</span>"
      when item.category == 'cycle_type'
        "<span class=\'sch_\'>only for</span>"
      when item.category == 'mnfg' || item.category == 'frame_mnfg'
        "<span class=\'sch_\'>Bikes made by</span>"
      else
        'Search for'
    "#{prefix} <span class=\'label\'>" + item.text + '</span>'

  # Don't include manufacturers if a manufacturer is selected
  setCategories: ->
    query = $("#bikes_search_form #query_items").val()
    query = [] if !query # Assign query to an array if it's blank
    # Soulheart doesn't support OR, only and for multiple categories.
    # TODO: Fix Soulheart so it does support multiple categories, and don't include cycle_type if a cycle_type is selected
    # queried_categories = query.filter (x) -> /^(v|m)_/.test(x)
    # if queried_categories.length == 0
    #   window.searchBarCategories = ""
    # else
    #   window.searchBarCategories = "colors"
    window.searchBarCategories = if /m_/.test(" #{query.join(" ")} ")
      "colors"
    else
      ""
