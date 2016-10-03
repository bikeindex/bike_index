class BikeIndex.BikesEditOwnership extends BikeIndex
  constructor: ->
    new window.CheckEmail('#bike_owner_email')
    @initializeEventListeners()
    @initializeAdditionalOrganizations()

  initializeEventListeners: ->
    $('#edit_bike_organizations').on 'click', '.remove-organization', (e) =>
      e.preventDefault()
      $formRow = $(e.target).parents('.form-group.row')
      $formRow.slideUp 400, =>
        $formRow.remove()
        @updateBikeOrganizations()

    $('#additional_organization_fields').on 'change', '.bike_organization_input', (e) =>
      @updateBikeOrganizations()

  initializeAdditionalOrganizations: ->
    add_organization_template = $('#additional-organization-template').html()
    Mustache.parse(add_organization_template)
    $('#add_additional_organization').click (e) =>
      e.preventDefault()
      $('#additional_organization_fields').append(Mustache.render(add_organization_template, { organizations: window.organizations }))
      @loadFancySelects()
      $('#additional_organization_fields .collapse').collapse('show')

  bikeOrganizationIds: ->
    _.compact( # remove nil values
      $('.bike_organization_static_input').get().map (i) -> $(i).data('orgid')
        .concat $('.bike_organization_input').get().map (i) -> i.value
    )

  updateBikeOrganizations: ->
    $('#bike_bike_organization_ids').val(@bikeOrganizationIds().join(','))
