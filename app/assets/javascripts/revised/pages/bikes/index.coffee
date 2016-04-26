class BikeIndex.BikesIndex extends BikeIndex
  constructor: ->
    new BikeIndex.BikeSearchBar
    setSearchProximity()

  initializeEventListeners: ->
    pagespace = @
    
  setSearchProximity: ->
    proximity = $('#proximity').val()
    unless proximity? and proximity.length > 0
      proximity = localStorage.getItem('location')
      proximity = "ip" unless proximity? and proximity.length > 0
      $('#proximity').val(proximity)
    localStorage.setItem('location', proximity)
    if document.getElementById('bikes-search') # set up search view if we're on bike search
      @setSearchTabInfo(proximity)

  setSearchTabInfo: (proximity) ->
    $('#search_distance').text($('#proximity_radius').val())
    $('#search_location').text(proximity)
    insertTabCounts = @insertTabCounts
    $.ajax
      type: "GET"
      url: $('#search_tabs').attr('data-url')
      success: (data) ->
        insertTabCounts(data)

  insertTabCounts: (counts) ->
    $("#stolen_tab .count").text("(#{counts.stolen})")
    $("#proximity_tab .count").text("(#{counts.proximity})")
    $("#non_stolen_tab .count").text("(#{counts.non_stolen})")