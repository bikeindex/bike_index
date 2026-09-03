class BikeIndex.OrganizedManageLocations extends BikeIndex
  $locations_fieldsets = $('#locations_fieldsets')

  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    loadFancySelects = @loadFancySelects
    updateVisibilityChecks = @updateVisibilityChecks
    updateImpoundedChecks = @updateImpoundedChecks
    hideRemoveIfOnlyOne = @hideRemoveIfOnlyOne
    updateVisibilityChecks()
    updateImpoundedChecks()
    hideRemoveIfOnlyOne()

    $("form").on "click", ".remove_fields", (event) ->
      # We don't need to do anything except slide the input up, because the label is on it.
      $form = $(this).closest("fieldset").parents(".collapse")
      $form.collapse("hide")
      $form.find("input:required").attr("required", false)
      hideRemoveIfOnlyOne()
      true

    $("form").on "click", ".add_fields", (event) ->
      event.preventDefault()
      time = new Date().getTime()
      regexp = new RegExp($(this).data("id"), "g")
      $("#fieldsetend").before($(this).data("fields").replace(regexp, time))
      loadFancySelects()
      updateVisibilityChecks()
      hideRemoveIfOnlyOne()
      true

    # When checking the "organization show on map", hide/show publicly visible
    $("#organization_show_on_map").on "change", (event) ->
      updateVisibilityChecks()

    $("form").on "change", ".impoundLocationCheck", (event) ->
      updateImpoundedChecks()

    # On check of default impound location, make sure only one is checked
    $("form").on "change", ".defaultImpoundLocationCheck", (event) ->
      targetID = $(event.target).attr("id")
      $(".defaultImpoundLocationCheck").each ->
        $check = $(this)
        unless $check.attr("id") == targetID
          $check.prop("checked", false)
      updateImpoundedChecks()

  updateImpoundedChecks: ->
    # Hide the default impound location checks if there isn't more than one impound location
    if $(".impoundLocationCheck:checked").length > 1
      $(".defaultImpoundLocationCheckWrapper").collapse("show")
    else
      $(".defaultImpoundLocationCheckWrapper").collapse("hide")
      # If there is only one impound location checked, mark it the default
      if $(".impoundLocationCheck:checked").length == 1
        $defaultChecked = $(".impoundLocationCheck:checked").parents("fieldset").find(".defaultImpoundLocationCheck")
        $defaultChecked.prop("checked", true)
        $(".defaultImpoundLocationCheck").each ->
          $check = $(this)
          unless $check.attr("id") == $defaultChecked.attr("id")
            $check.prop("checked", false)

  updateVisibilityChecks: ->
    if $("#organization_show_on_map").prop("checked")
      visibility = "show"
    else
      visibility = "hide"
    $(".publiclyVisibilyCheck").collapse(visibility)

  hideRemoveIfOnlyOne: ->
    # Lazy HACK: wait for fields to finish collapsing
    setTimeout ( =>
      # We don't want to allow removing the final location, so hide remove if there is only one location
      if $(".locations-fieldset-wrapper .location-card:visible").length < 2
        $(".locations-fieldset-wrapper .location-card .remove-control").collapse("hide")
      else
        $(".locations-fieldset-wrapper .location-card .remove-control").collapse("show")
    ), 500
