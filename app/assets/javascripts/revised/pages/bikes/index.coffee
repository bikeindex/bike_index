class BikeIndex.BikesIndex extends BikeIndex
  constructor: ->
    new BikeIndex.BikeSearchBar

  initializeEventListeners: ->
    pagespace = @
    
    # $('#thumbnails .clickable-image').click (e) ->
    #   pagespace.clickPhoto(e)
    # # Rotate photos on arrow key presses
    # $(document).keyup (e) ->
    #   pagespace.rotatePhotosOnArrows(e)
    # # If the window scrolls, load photos, so that there isn't a delay when clicking
    # # on them - and so we don't load them unless there is interaction with the page
    # $(window).scroll ->
    #   pagespace.loadPhotos()
    #   $(window).unbind('scroll')

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