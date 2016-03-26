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
    @initializeHeaderSearch()
    @loadFancySelects()
    @setLightspeedMovie() if $('#lightspeed-tutorial-video').length > 0
    if $('#what-spokecards-are').length > 0
      $('.spokecard-extension').addClass('on-spokecard-page')
    @intializeContent() if $('.content-nav').length > 0
    
  openNewWindow: (e) ->
    e.preventDefault()
    target = $(e.target)
    local = target.attr("data-target")
    if target.hasClass('same-window')
      window.location = local
    else
      window.open(local, '_blank')

  loadFancySelects: ->
    $('.chosen-select select').selectize() # legacy
    $('.special-select-single select').selectize
      create: false

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

  updateIncludeSerialOption: ->
    # Check if the header search includes the serial string match, set it on the window
    window.includeSerialOption = !($('#head-search-bikes #query').val().match(/s(#|%23)[^(#|%23)]*(#|%23)/))

  initializeHeaderSearch: ->
    initial_opts = $('#selectize_items').data('initial')
    per_page = 10
    renderOption = @renderOption
    updateIncludeSerialOption = @updateIncludeSerialOption
    $('#head-search-bikes #query').selectize
      plugins: ['restore_on_backspace', 'remove_button']
      preload: true
      create: true
      options:  initial_opts # So that they have words
      items: initial_opts.map (i) -> i.search_id
      persist: false # Don't show items the users has entered after deleting them
      valueField: 'search_id'
      labelField: 'text'
      searchField: 'text'
      load: (query, callback) ->
        $.ajax
          url: "/api/autocomplete?per_page=#{per_page}&q=#{encodeURIComponent(query)}"
          type: 'GET'
          error: ->
            callback()
          success: (res) ->
            result = res.matches.slice(0, per_page)
            result.push({ id: 'serial', search_id: "s##{query}#", text: "#{query}" }) if window.includeSerialOption
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