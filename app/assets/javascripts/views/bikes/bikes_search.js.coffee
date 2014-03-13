class BikeIndex.Views.BikesSearch extends Backbone.View

  initialize: ->
    @setElement($('#body'))
    @setInitialValues()
    $('.content .receptacle').addClass('bike-search-page')

  setInitialValues: ->
    $('#header-search .optional-fields').show()
    if $('#serial').val() == "absent"
      $('#serial-absent, .absent-serial-blocker').addClass('absents')
      $('#serial').addClass('absent-serial')
    if $('#stolenness_query').attr('data-stolen')
      $('#stolen-proximity')
        .show()
        .addClass('unhidden')
        .find('span').show()