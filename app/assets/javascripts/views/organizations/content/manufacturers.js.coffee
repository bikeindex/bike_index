class BikeIndex.Views.ContentManufacturers extends Backbone.View

  initialize: ->
    @loadDataTable('#manufacturers-list')


  loadDataTable:(table_id) ->
    $(table_id).dataTable(
      "aaSorting": [ ]
      "aLengthMenu": [[5, 10, 50, 100, -1], [5, 10, 50, 100, "All"]]
      "iDisplayLength": '5'
      "sDom": "<'row-fluid'<'span6'l><'span6'f>r>t<'row-fluid'<'span12'i>>"
      )
