class BikeIndex.Views.Global extends Backbone.View
  events:
    'click #nav-header-collapse':           'toggleCollapsibleHeader'
    'click #header-tabs .expand_t a':       'expandHeaderTab'
    'click .footnote-ref':                  'scrollToRef'
    'click .footnote-back-link':            'scrollToRef'
    'click .scroll-to-ref':                 'scrollToRef'
    'click .no-tab':                        'openNewWindow'
    'click #expand_user':                   'expandUserNav'
    'click #most_recent_stolen_bikes':      'mostRecentStolen'
    
  initialize: ->
    # BikeIndex.hideFlash() # not sure that it's something we ever want
    @setElement($('#body'))
    @initializeHeaderSearch() if document.getElementById('head-search-bikes')
    @loadFancySelects()
    @setLightspeedMovie() if $('#lightspeed-tutorial-video').length > 0
    if $('#what-spokecards-are').length > 0
      $('.spokecard-extension').addClass('on-spokecard-page')
    @intializeContent() if $('.content-nav').length > 0

    # Pulled from init, because we need it in admin
    @localizeTimes()

  displayLocalDate: (time, preciseTime = false) ->
    # Ensure we return if it's a big future day
    if time < window.tomorrow
      if time > window.today
        return time.format("h:mma")
      else if time > window.yesterday
        return "Yday #{time.format('h:mma')}"
    if time.year() == moment().year()
      if preciseTime then time.format("MMM Do[,] h:mma") else time.format("MMM Do[,] ha")
    else
      if preciseTime then time.format("YYYY-MM-DD h:mma") else time.format("YYYY-MM-DD")

  localizeTimes: ->
    window.timezone ||= moment.tz.guess()
    moment.tz.setDefault(window.timezone)
    window.yesterday = moment().subtract(1, "day").startOf("day")
    window.today = moment().startOf("day")
    window.tomorrow = moment().endOf("day")
    displayLocalDate = @displayLocalDate
    $(".convertTime").each ->
      $this = $(this)
      $this.removeClass("convertTime")
      text = $this.text().trim()
      return unless text.length > 0
      time = moment(text, moment.ISO_8601)
      return unless time.isValid()
      $this.text(displayLocalDate(time, $this.hasClass("preciseTime")))

    # Write timezone
    $(".convertTimezone").each ->
      $this = $(this)
      $this.text(moment().format("z"))
      $this.removeClass("convertTimezone")
    $(".hiddenFieldTimezone").val(window.timezone)
    
  openNewWindow: (e) ->
    e.preventDefault()
    target = $(e.target)
    local = target.attr("data-target")
    if target.hasClass('same-window')
      window.location = local
    else
      window.open(local, '_blank')

  loadFancySelects: ->
    $('.chosen-select select').selectize # legacy
      create: false
      plugins: ['restore_on_backspace']
    $('.special-select-single select').selectize
      create: false
      plugins: ['restore_on_backspace']
    $('.special-select-single-placeholder select').selectize # When empty options are allowed
      create: false
      plugins: ['restore_on_backspace', 'selectable_placeholder']

  scrollToRef: (event) ->
    event.preventDefault()
    target = $(event.target).attr('href')
    $('body').animate( 
      scrollTop: ($(target).offset().top - 20), 'fast' 
    )

  #
  #
  # Updated header nav stuff

  mostRecentStolen: (e) ->
    e.preventDefault()
    $('#stolen').val('true')
    $('#head-search-bikes').submit()

  expandUserNav: (event) ->
    event.preventDefault()
    $('.top-user-nav').slideToggle()

  setSearchProximity: ->
    proximity = $('#proximity').val()
    unless proximity? and proximity.length > 0
      proximity = localStorage.getItem('location')
      proximity = "ip" unless proximity? and proximity.length > 0
      $('#proximity').val(proximity)
    localStorage.setItem('location', proximity)
    if document.getElementById('bikes-search') # set up search view if we're on bike search
      @setSearchTabInfo(proximity)

  setSearchTabInfo: (proximity) ->
    $('#search_distance').text($('#proximity_radius').val())
    $('#search_location').text(proximity)
    insertTabCounts = @insertTabCounts
    $.ajax
      type: "GET"
      url: $('#search_tabs').attr('data-url')
      success: (data) ->
        insertTabCounts(data)

  insertTabCounts: (counts) ->
    $("#stolen_tab .count").text("(#{counts.stolen})")
    $("#proximity_tab .count").text("(#{counts.proximity})")
    $("#non_stolen_tab .count").text("(#{counts.non_stolen})")


  updateIncludeSerialOption: ->
    # Check if the header search includes the serial string match, set it on the window
    window.includeSerialOption = !($('#head-search-bikes #query').val().match(/s(#|%23)[^(#|%23)]*(#|%23)/))

  initializeHeaderSearch: ->
    @setSearchProximity() # Call here, since we only want to call if search exists
    initial_opts = []
    initial_opts = $('#selectize_items').data('initial') if $('#selectize_items').data('initial')
    per_page = 15
    renderOption = @renderOption
    updateIncludeSerialOption = @updateIncludeSerialOption
    $('#head-search-bikes #query').selectize
      plugins: ['restore_on_backspace', 'remove_button']
      create: true
      options:  initial_opts # So that they have words
      items: initial_opts.map (i) -> i.search_id
      persist: false # Don't show items the users has entered after deleting them
      valueField: 'search_id'
      preload: true
      labelField: 'text'
      searchField: 'text'
      loadThrottle: 150
      score: (search) ->
        score = this.getScoreFunction(search)
        return (item) ->
          if item.id == 'serial'
            # Only show serial query that is the same as the query we've entered
            if search == item.search && search.length > 2
              return 0.0001
            else
              return 0
          else
            score(item) * (1 + Math.min(item.priority / 100, 1))
      sortField: 'priority'
      load: (query, callback) ->
        that = this
        $.ajax
          url: "/api/autocomplete?per_page=#{per_page}&q=#{encodeURIComponent(query)}"
          type: 'GET'
          error: ->
            callback()
          success: (res) ->
            result = res.matches.slice(0, per_page)
            # Only add serial option if they've entered more than 2 char
            if query.length > 2 && window.includeSerialOption
              result.push({ id: 'serial', search_id: "s##{query}#", text: "#{query}", search: query })
            callback result
      render:
        option: (item, escape) ->
          renderOption(item, escape)
        item: (item, escape) ->
          if item.id == 'serial'
            "<div><span class='search_span_s'>serial</span> #{item.text}</div>"
          else  
            "<div> #{item.text}</div>"
        option_create: (data, escape) ->
          # For some reason, without &hellip; at the end of this it breaks
          "<div class='create'><span class='sch_'>Search all bikes for</span> <span class='label'>" + escape(data.input) + "</span>&hellip;</div>"
      onChange: (value) ->
        # On change doesn't cover everything, so run it all the time
        updateIncludeSerialOption()
        true
      onType: (str) ->
        for k in Object.keys(this.options)
          # If they are serial ids
          if k.match /^s\#/ 
            # if the serials are longer than the current str, delete them
            # Also delete them if we're down to 2 chars
            delete this.options[k] if (k.length > str + 3) || str.length < 3
        true
      onItemAdd: (value, $item) ->
        updateIncludeSerialOption()
        true
      onItemRemove: (value) ->
        updateIncludeSerialOption()
        true
      onInitialize: ->
        updateIncludeSerialOption()

  renderOption: (item, escape) ->
    prefix = switch
      when item.category == 'colors'
        p = "<span class='sch_'>Bikes that are </span>"
        if item.display
          p + "<span class='sclr' style='background: #{item.display};'></span>"
        else
          p + "<span class='sclr'>stckrs</span>"
      when item.category == 'mnfg' || item.category == 'frame_mnfg'
        "<span class='sch_'>Bikes made by</span>"
      when item.id == 'serial' # because we set this item up in the success callback
        "<span class='sch_'>Find serial</span>"
      else
        'entered'
    "<div>#{prefix} <span class='label'>" + escape(item.text) + '</span></div>'

  # 
  # 
  # Page specific things I've been too lazy to make separate backbone views

  setLightspeedMovie: ->
    height = '394'
    height = '315' if $(window).width() < 768
    video = """<iframe width="100%" height="#{height}" src="//www.youtube.com/embed/XW1ieMEwkvY" frameborder="0" allowfullscreen></iframe>"""
    $('#lightspeed-tutorial-video').append(video)


  loadStolenWidget: (location) ->
    $.ajax
      type: "GET"
      url: 'https://freegeoip.net/json/'
      dataType: "jsonp",
      success: (location) ->
        $('#stolen-proximity #proximity').val("#{location.region_name}")
        loadStolenWidget(location) if $('#sbr-body').length > 0      



  # 
  # 
  # Old layout things. Delete once everything is updated

  toggleCollapsibleHeader: ->
    # This is for the content pages where the search header is hidden
    $('#total-top-header').find('.search-background').toggleClass('show')
    $('#total-top-header').find('.background-extend').toggleClass('show')
    $('#total-top-header').find('.search-fields').toggleClass('show')
    $('#total-top-header').find('.global-tabs').toggleClass('show')
    $('#header').toggleClass('invisibled')
    $('#nav-header-collapse').toggleClass('expandable')
    if $('#content-wrap').length > 0
      $('#content-wrap').toggleClass('header-closed')

  expandHeaderTab:(event) ->
    event.preventDefault()
    target = $(event.target)
    if target.parents('li').hasClass('active')
      $('#header-tabs .global-tabs li').removeClass('active')
      $('#header-tabs').removeClass('visibled')
      $('#total-top-header').removeClass('header-tabs-in')
    else 
      # console.log(target)
      # $('#session_email').focus() if target.hasClass('.expand-sign-in')
      # console.log('hihih')
      window.setTimeout (->
        $('#session_email').focus()
      ), 500
      
      
      $('#total-top-header').addClass('header-tabs-in')
      if $('#header-tabs .tab-content').hasClass('visibled') 
        target.tab('show')
      else
        $('#header-tabs').addClass('visibled')
        target.tab('show')

  intializeContent: ->
    # Add margin to the top of page content so that it doesn't break
    h = $('.active-menu ul').height() - 40
    $('#content-top-margin').css('margin-top', "#{h}px")
    if $('#main-faq-block').length > 0
      url = window.location.href
      idx = url.indexOf("#")
      anchor = if idx != -1 then url.substring(idx+1)
      if anchor?
        $("##{anchor}").collapse()

   
  # loadUserHeader: ->
    # This is minified and inlined in the header in legacy pages
    # 
    # $('#header-tabs').prepend("<div id='tab-cover'></div>")
    # $.ajax({
    #   type: "GET"
    #   url: '/api/v1/users/current'
    #   success: (data, textStatus, jqXHR) ->
    #     if data["user_present"]
    #       $('#total-top-header .yes_user').removeClass('hidden')
    #       if data["is_superuser"]
    #         $('#total-top-header .super_user').removeClass('hidden')
    #       if _.isArray(data["memberships"])
    #         for membership in data["memberships"]
    #           tab = """
    #             <li class="expand_t">
    #               <a href="##{membership["slug"]}">#{membership["short_name"]}</a>
    #             </li>
    #           """
    #           links = """
    #             <div class="tab-pane" id="#{membership["slug"]}">
    #               <ul>
    #                 <li>
    #                   <a href="/bikes/new?creation_organization_id=#{membership["organization_id"]}">
    #                     <strong>Add a bike</strong> through #{membership["organization_name"]}
    #                   </a>
    #                 </li>
    #                 <li>
    #                   <a href="#{membership["base_url"]}">
    #                     #{membership["organization_name"]} Account
    #                   </a>
    #                 </li>
    #           """
    #           if membership["is_admin"]
    #             links = links + """
    #               <li>
    #                 <a href="#{membership["base_url"]}/edit">
    #                   Manage organization
    #                 </a>
    #               </li>
    #             """
    #           links = links + "</ul></div>"
    #           $('#total-top-header .global-tabs').append(tab)
    #           $('#total-top-header .tab-content').append(links)
    #       $('#your_settings_n_stuff').text(data["email"]) if data["email"]
    #       $('#tab-cover').fadeOut()
    #     else
    #       $('#total-top-header .no_user').removeClass('hidden')
    #       $('#tab-cover').fadeOut()
    #   error: (data, textStatus, jqXHR) ->
    #     $('#total-top-header .no_user').removeClass('hidden')
    #     $('#tab-cover').fadeOut()
    #     BikeIndex.alertMessage("error", "User load error", "We're sorry, we failed to load your user information. Try reloading maybe?")
    #   })