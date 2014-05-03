class BikeIndex.Views.OrganizationsShow extends Backbone.View
  events:
    'click #show-developer-info':           'showDeveloperInfo'
    'click #show-lightspeed-info':          'showLightspeedInfo'


  initialize: ->
    @setElement($('#body'))
    # Later we can seperate these, for now though here is good enough
    if $('#org-bikes-table').length > 0
      @loadDataTable('#org-bikes-table')
    else if $('#org-users-table').length > 0
      @loadDataTable('#org-users-table')   

  loadDataTable:(table_id) ->
    $(table_id).dataTable(
      "aaSorting": [ ]
      "aLengthMenu": [[25, 50, 100, 200, -1], [25, 50, 100, 200, "All"]]
      "iDisplayLength": '25'
      "sDom": "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span6'i><'span6'p>>"
      "sPaginationType": "bootstrap"
      )

  showDeveloperInfo: (event) ->
    event.preventDefault()
    $('#developer-info').slideToggle()
    $(event.target).toggleClass('shown')

  showLightspeedInfo: (event) ->
    event.preventDefault()
    $('#lightspeed-info').slideToggle()
    $(event.target).toggleClass('shown')


