class BikeIndex.Views.BikesSearch extends Backbone.View
  events:
    # 'change .with-additional-block select': 'expandAdditionalBlock'
    'click #proximity_tab': 'proximitySearch'
    'click #stolen_tab': 'stolenSearch'
    'click #non_stolen_tab': 'nonStolenSearch'


  initialize: ->
    $('.stolen-search-link').hide()
    $('.stolen-search-fields').show()
    @setElement($('#body'))
    @setInitialValues()
    $('.content .receptacle').addClass('bike-search-page')

  setInitialValues: ->
    that = this
    proximity = $('#proximity').val()
    unless proximity? and proximity.length > 0
      proximity = localStorage.getItem('location')
      proximity = "ip" unless proximity? and proximity.length > 0
      $('#proximity').val(proximity)
    $('#search_distance').text($('#proximity_radius').val())
    $('#search_location').text(proximity)

    $.ajax
      type: "GET"
      url: $('#search_tabs').attr('data-url')
      success: (data) ->
        that.insertCounts(data)    
    localStorage.setItem('location', proximity)

  insertCounts: (counts) ->
    $("#stolen_tab .count").text("(#{counts.stolen})")
    $("#proximity_tab .count").text("(#{counts.proximity})")
    $("#non_stolen_tab .count").text("(#{counts.non_stolen})")

  stolenSearch: (e) ->
    e.preventDefault()
    $('#stolen').val('true')
    $('#non_stolen').val('')
    $('#non_proximity').val('true')
    $('#head-search-bikes').submit()

  nonStolenSearch: (e) ->
    e.preventDefault()
    $('#stolen').val('')
    $('#non_stolen').val('true')
    $('#head-search-bikes').submit()

  proximitySearch: (e) ->
    e.preventDefault()
    $('#stolen').val('true')
    $('#non_stolen').val('')
    $('#non_proximity').val('')
    $('#head-search-bikes').submit()
