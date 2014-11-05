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
    if $('#edit-organization-page').length > 0
      @initializeLocationEdit()
      $('.chosen-select select').select2()

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
      
  initializeLocationEdit: ->
    $('form').on 'click', '.remove_fields', (event) ->
      # We don't need to do anything except slide the input up, because the label is on it.
      $(this).closest('fieldset').slideUp()
      # event.preventDefault()
    $('form').on 'click', '.add_fields', (event) ->
      time = new Date().getTime()
      regexp = new RegExp($(this).data('id'), 'g')
      $(this).before($(this).data('fields').replace(regexp, time))
      event.preventDefault()
      us_val = parseInt($('#us-country-code').text(), 10)
      for location in $(this).closest('fieldset').find('.country_select_container select')
        l = $(location)
        l.val(us_val) unless l.val().length > 0
      names = $(this).closest('fieldset').find('.location-name-field input')
      for name in names
        n = $(name)
        n.val($('#organization_name').val()) unless n.val().length > 0
      
      $('.chosen-select select').select2()