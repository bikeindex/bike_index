class BikeIndex.BikesEditGroups extends BikeIndex
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
    window.addOrganizationTemplate = $('#additional-organization-template').html()
    Mustache.parse(window.addOrganizationTemplate)
    $('#add_additional_organization').click (e) =>
      e.preventDefault()
      @addAdditionalOrganizationSelector()
    # We also want to add one organization on page load
    @addAdditionalOrganizationSelector()

  addAdditionalOrganizationSelector: ->
    $('#additional_organization_fields').append(Mustache.render(window.addOrganizationTemplate, { organizations: window.organizations }))
    @loadFancySelects()
    $('#additional_organization_fields .collapse').collapse('show')

  bikeOrganizationIds: ->
    _.compact( # remove nil values
      $('.bike_organization_static_input').get().map (i) -> $(i).data('orgid')
        .concat $('.bike_organization_input').get().map (i) -> i.value
    )

  updateBikeOrganizations: ->
    $('#bike_bike_organization_ids').val(@bikeOrganizationIds().join(','))
