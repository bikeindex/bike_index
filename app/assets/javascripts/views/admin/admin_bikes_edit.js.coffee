class BikeIndex.Views.AdminBikesEdit extends Backbone.View
    
  initialize: ->
    window.root_url = $('#bike_edit_root_url').attr('data-url')
    @setElement($('#body'))
    @initializeFrameMaker("#bike_manufacturer_id")
    
  initializeFrameMaker: (target) ->
    url = "#{window.root_url}/api/searcher?types[]=frame_makers&"
    $(target).select2
      minimumInputLength: 2
      placeholder: 'Choose manufacturer'
      ajax:
        url: url
        dataType: "json"
        openOnEnter: true
        data: (term, page) ->
          term: term # search term
          limit: 10
        results: (data, page) -> # parse the results into the format expected by Select2.
          remapped = data.results.frame_makers.map (i) -> {id: i.id, text: i.term}
          results: remapped
      initSelection: (element, callback) ->
        id = $(element).val()
        if id isnt ""
          $.ajax("#{window.root_url}/api/v1/manufacturers/#{id}",
          ).done (data) ->
            data =
              id: element.val()
              text: data.manufacturer.name
            callback data