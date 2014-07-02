class BikeIndex.Views.Global extends Backbone.View
  events:
    'click #nav-header-collapse':           'toggleCollapsibleHeader'
    'click #header-tabs .expand_t a':       'expandHeaderTab'
    'click .footnote-ref':                  'scrollToRef'
    'click .footnote-back-link':            'scrollToRef'
    'click .scroll-to-ref':                 'scrollToRef'
    'click .no-tab':                        'openNewWindow'
    'click #serial-absent':                 'updateSerialAbsent'
    'focus #header-search':                 'expandSearch'
    'change input#stolen':                  'toggleProximitySearch'
    'change #head-search-bikes #query':     'updateManufacturerSearch'
    # 'click #search-type-tabs':              'toggleSearchType'
    
  initialize: ->
    BikeIndex.hideFlash()
    @setElement($('#body'))
    on_stolen = false
    if $('#sbr-body').length > 0
      that = @
      $('#search-type-tabs').click (e) ->
        that.toggleSearchType(e)
    else
      @initializeHeaderSearch()
      @loadChosen() if $('#chosen-container').length > 0
      @setLightspeedMovie() if $('#lightspeed-automation').length > 0
      if $('#what-spokecards-are').length > 0
        $('.spokecard-extension').addClass('on-spokecard-page')
    @setProximityLocation()
    

  setLightspeedMovie: ->
    height = '394'
    height = '315' if $(window).width() < 768
    video = """<iframe width="100%" height="#{height}" src="//www.youtube.com/embed/52QTFWm7gHk" frameborder="0" allowfullscreen></iframe>"""
    $('#lightspeed-tutorial-video').append(video)
    
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
  

  initializeHeaderSearch: ->
    unless $('#sbr-body').length > 0
      tags = JSON.parse($("#header-search").attr('data-options'))
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
              return "#{object.text} <span class='sch_s'><span>lookup </span>serial</span>"
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
        data.push({id: '#', text: $('#header-search #serial').val()})
        $('#query').select2('data',data)

  updateManufacturerSearch: (e) ->
    if e.added?
      unless e.added.id == e.added.text 
        if e.added.id == '#'
          $('#header-search #serial').val(e.added.text)
    if e.removed?
      if e.removed.id == '#'
        $('#header-search #serial').val('')

  updateSerialAbsent: (e) ->
    e.preventDefault()
    $('#serial-absent, .absent-serial-blocker').toggleClass('absents')
    if $('#serial-absent').hasClass('absents')
      $('#serial')
        .val('absent')
        .addClass('absent-serial')
    else
      $('#serial')
        .val('')
        .removeClass('absent-serial')

  loadStolenWidget: (location) ->
    $.ajax
      type: "GET"
      url: 'https://freegeoip.net/json/'
      dataType: "jsonp",
      success: (location) ->
        $('#stolen-proximity #proximity').val("#{location.region_name}")
        loadStolenWidget(location) if $('#sbr-body').length > 0

  toggleSearchType: (e) ->
    e.preventDefault()
    target = $(e.target)
    target = target.parents('a') if target.is('span')
    unless $(target).hasClass('active')
      $('.search-type-tab').toggleClass('active')
      $('#search_type').val(target.attr('data-stype'))

  toggleProximitySearch: ->
    if $('#stolen-proximity').hasClass('unhidden')
      $('#stolen-proximity span').fadeOut 100, ->
        $('#stolen-proximity')
          .slideUp "medium"
          .removeClass('unhidden')
    else
      $('#stolen-proximity').slideDown "medium", ->
        $('#stolen-proximity span').fadeIn 100
        $('#stolen-proximity').addClass('unhidden')
        

  setProximityLocation: ->
    # if $('#stolenness_query').length > 0 && $('#stolenness_query').attr('data-stolen').length > 0
    #   return true
    # $.ajax
    #   type: "GET"
    #   url: 'https://freegeoip.net/json/'
    #   dataType: "jsonp",
    #   success: (location) ->
    #     $('#stolen-proximity #proximity').val("#{location.region_name}")
    #     # loadStolenWidget(location) if $('#sbr-body').length > 0
  
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

  scrollToRef: (event) ->
    event.preventDefault()
    target = $(event.target).attr('href')
    $('body').animate( 
      scrollTop: ($(target).offset().top - 20), 'fast' 
    )

  intializeContent: ->
    if $(window).width() > 650 
      $('#content-menu').addClass('affix')
      footer_offset = $('#page-foot').offset().top
      menu = $('#content-menu')
      tp = menu.css('padding-top')
      bp = menu.css('padding-bottom')
      menu_height = menu.height()
      b_offset = footer_offset - ( menu_height + 120 ) 
      
      $("<style>#content-menu.affix{top:#{b_offset}px};</style>").appendTo('head')
      $('#content-menu').attr('data-spy', 'affix').attr('data-offset-top', (b_offset))

  expandSearch: ->
    # unless $('#total-top-header').hasClass('search-expanded')
    #   $('#header-search .optional-fields').fadeIn()

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