class BikeIndex.InfoManufacturers extends BikeIndex
  constructor: ->
    @loadDataTable('#manufacturers-list')

  loadDataTable:(table_id) ->
    $(table_id).dataTable(
      "aaSorting": [ ]
      "aLengthMenu": [[5, 10, 50, 100, -1], [5, 10, 50, 100, "All"]]
      "iDisplayLength": 5
      )
