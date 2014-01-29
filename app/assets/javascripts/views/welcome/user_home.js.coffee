class BikeIndex.Views.UserHome extends Backbone.View
  initialize: ->
    @setElement($('#body'))
    if $('#user-bikes-table').length > 0
      @loadDataTable('#user-bikes-table')
    

  loadDataTable:(table_id) ->
    $(table_id).dataTable(
      "aaSorting": [ ]
      "aLengthMenu": [[25, 50, 100, 200, -1], [25, 50, 100, 200, "All"]]
      "iDisplayLength": '50'
      "sDom": "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span6'i><'span6'p>>"
      "sPaginationType": "bootstrap"
      )

