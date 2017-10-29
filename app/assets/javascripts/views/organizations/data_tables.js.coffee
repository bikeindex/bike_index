class BikeIndex.Views.DataTables extends Backbone.View

  initialize: ->
    # Later we can seperate these, for now though here is good enough
    if $('#truncated-data-table').length > 0
      @loadDataTable('#truncated-data-table')
    else if $('#admin-users-table').length > 0
      @loadDataTable('#admin-users-table')
    else if $('#admin-manufacturers-list').length > 0
      @loadDataTable('#admin-manufacturers-list')
    else if $('#admin-ads-table').length > 0
      @loadDataTable('#admin-ads-table')
    else if $('#admin-bikes-index').length > 0
      $('#admin-bikes-index').dataTable
        aaSorting: [ ]
        aLengthMenu: [[25, 50, 100, 200, -1], [25, 50, 100, 200, "All"]]
        iDisplayLength: -1

  loadDataTable:(table_id) ->
    $(table_id).dataTable
      aaSorting: [ ]
      aLengthMenu: [[25, 50, 100, 200, -1], [25, 50, 100, 200, "All"]]
      iDisplayLength: -1
