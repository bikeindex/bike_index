class BikeIndex.OrganizedManageLocations extends BikeIndex
  $locations_fieldsets = $('#locations_fieldsets')
  default_country = $locations_fieldsets.data('country')
  default_name = $locations_fieldsets.data('name')

  constructor: ->
    @initializeEventListeners()

  initializeEventListeners: ->
    setDefaultCountryAndName = @setDefaultCountryAndName
    loadFancySelects = @loadFancySelects
    $('form').on 'click', '.remove_fields', (event) ->
      # We don't need to do anything except slide the input up, because the label is on it.
      $(this).closest('fieldset').slideUp()
      # event.preventDefault()
    $('form').on 'click', '.add_fields', (event) ->
      event.preventDefault()
      time = new Date().getTime()
      regexp = new RegExp($(this).data('id'), 'g')
      $('#fieldsetend').before($(this).data('fields').replace(regexp, time))
      setDefaultCountryAndName()
      loadFancySelects()


  setDefaultCountryAndName: ->
    for country in $locations_fieldsets.find('.location-country-select select')
      $country = $(country)
      return true if $country.val().length > 0
      country_selectize = $country.selectize()[0].selectize
      index = _.indexOf(Object.keys(country_selectize.options), "#{default_country}")
      country_selectize.setValue Object.keys(country_selectize.options)[index]
    for name in $locations_fieldsets.find('.location-name-field')
      $name = $(name)
      $name.val(default_name) unless $name.val().length > 0
