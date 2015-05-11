class BikeIndex.Views.Global extends Backbone.View
  events:
    'click #nav-header-collapse':           'toggleCollapsibleHeader'
    'click #header-tabs .expand_t a':       'expandHeaderTab'
    'click .footnote-ref':                  'scrollToRef'
    'click .footnote-back-link':            'scrollToRef'
    'click .scroll-to-ref':                 'scrollToRef'
    'click .no-tab':                        'openNewWindow'
    'change #head-search-bikes #query':     'updateSearchAssociations'
    'click #expand_user':                   'expandUserNav'
    'click #most_recent_stolen_bikes':      'mostRecentStolen'
    
  initialize: ->
    # BikeIndex.hideFlash() # not sure that it's something we ever want
    @setElement($('#body'))
    @initializeHeaderSearch()
    @loadChosen() if $('#chosen-container').length > 0
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

  loadChosen: ->
    $('.chosen-select select').select2()

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

  initializeHeaderSearch: ->
    tags = JSON.parse($("#header-search-select").attr('data-options'))
    $('#head-search-bikes #query').select2
      tags: tags
      tokenSeparators: [","]
      openOnEnter: false
      formatResult: (object, container, query) ->
        if object.id?
          return nil unless query?
          if object.display
            return "#{object.display} <span class='sch_c'>#{object.text}</span>"
          if object.id == '#'
            return "<span class='sch_s'><span>Find </span>serial</span> #{object.text}"
          if object.id == object.text
            return "<span class='sch_'>Search <span>all bikes</span> for</span> #{object.text}"
          else
            "<span class='sch_m'><span>Bikes </span>made by</span> #{object.text}"
      formatResultCssClass: (o) ->
        'sch_special' if o.id == '#'
        # return response + object.text
      createSearchChoice: (term, data) ->
        if $(data).filter(->
          @text.localeCompare(term) is 0
        ).length is 0
          id: term
          text: term
      createSearchChoicePosition: (list, item) ->
        list.splice 0, 0, item, {id: '#', text: item.text }
      dropdownCssClass: 'mainsrchdr'
      formatSelection: (object, containter) ->
        return object.text if object.id == object.text
        if object.id == '#'
          return "<span class='search_span_s'>serial </span> #{object.text}"
        else if object.display?
          return object.text
        "<span class='search_span_m'>made by </span> #{object.text}"
    
    # if $('#header-search #manufacturer_id').val().length > 0
    #   data = $('#query').select2('data')
    #   data.push($('#header-search').data('selected'))
    #   $('#query').select2('data',data)
    if $('#header-search #serial').val().length > 0
      data = $('#query').select2('data')
      data.push({id: '#', text: encodeURI($('#header-search #serial').val())})
      $('#query').select2('data',data)

    unless $('#bikes-search').length > 0
      location = localStorage.getItem('location')
      $('#proximity').val(localStorage.getItem('location'))
      unless location? and location.length > 0
        $('#proximity').val('ip')
        localStorage.setItem('location', 'ip')
        $.getJSON "https://freegeoip.net/json/", (json) ->
          location = ""
          location += "#{json.city} " if json.city?
          location += "#{json.region_name}" if json.region_name?
          if location.length > 0
            localStorage.setItem('location', location)
            $('#proximity').val(location)

  updateSearchAssociations: (e) ->
    if e.added?
      unless e.added.id == e.added.text 
        if e.added.id == '#'
          $('#header-search #serial').val(e.added.text)
    if e.removed?
      if e.removed.id == '#'
        $('#header-search #serial').val('')




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
    # This is minified and inlined in the header
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