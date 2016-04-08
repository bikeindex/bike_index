class BikeIndex.ManufacturersSelect extends BikeIndex
  constructor: (target_selector, frame_mnfg = true) ->
    $target = $(target_selector)
    initial_opts = []
    initial_opts = [$target.data('initial')] if $target.data('initial')
    return true unless $target.hasClass('unfancy')
    per_page = 10
    if frame_mnfg
      url = "#{window.root_url}/api/autocomplete?per_page=#{per_page}&categories=frame_mnfg&q="
      value_field = 'slug' # for convenience in viewing, also functionality without JS
    else
      url = "#{window.root_url}/api/autocomplete?per_page=#{per_page}&categories=frame_mnfg+mnfg&q="
      value_field = 'id' # for convenience instantiating
    $target.selectize
      plugins: ['restore_on_backspace']
      # preload: true # Not unless we get pagination, since it confuses people
      options: initial_opts
      persist: false
      create: false
      maxItems: 1
      selectOnTab: true
      valueField: value_field
      labelField: 'text'
      searchField: 'text'
      loadThrottle: 130
      score: (search) ->
        score = this.getScoreFunction(search)
        return (item) ->
          score(item) * (1 + Math.min(item.priority / 100, 1))
      load: (query, callback) ->
        $.ajax
          url: "#{url}#{encodeURIComponent(query)}"
          type: 'GET'
          error: ->
            callback()
          success: (res) ->
            callback res.matches.slice(0, per_page)
    $target.removeClass('unfancy') # So we don't instantiate multiple times
