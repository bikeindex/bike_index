class BikeIndex.Views.Global extends Backbone.View
  events:
    'click #nav-header-collapse': 'toggleCollapsibleHeader'
    'click #header-tabs .expand_t a': 'expandHeaderTab'
    'click .footnote-ref': 'scrollToFootnote'
    'click .footnote-back-link': 'scrollToFootnote'
    'click .scroll-to-ref': 'scrollToFootnote'
    'click .no-tab': 'openNewWindow'
    
  initialize: ->
    BikeIndex.hideFlash()
    @setElement($('#body'))
    @initializeHeaderSearch()
    @loadChosen() if $('#chosen-container').length > 0
    @loadUserHeader()

  loadUserHeader: ->
    $.ajax({
      type: "GET"
      url: '/api/v1/users/current'
      success: (data, textStatus, jqXHR) ->
        if data["user_present"]
          $('#total-top-header .yes_user').removeClass('hidden')
          if data["is_superuser"]
            $('#total-top-header .super_user').removeClass('hidden')
          if _.isArray(data["memberships"])
            for membership in data["memberships"]
              
              tab = """
                <li class="expand_t">
                  <a href="##{membership["slug"]}">#{membership["short_name"]}</a>
                </li>
              """

              links = """
                <div class="tab-pane" id="#{membership["slug"]}">
                  <ul>
                    <li>
                      <a href="/bikes/new?creation_organization_id=#{membership["organization_id"]}">
                        <strong>Add a bike</strong> through #{membership["organization_name"]}
                      </a>
                    </li>
                    <li>
                      <a href="#{membership["base_url"]}">
                        #{membership["organization_name"]} Account
                      </a>
                    </li>
              """
              if membership["is_admin"]
                links = links + """
                  <li>
                    <a href="#{membership["base_url"]}manage">
                      Manage organization
                    </a>
                  </li>
                """

              links = links + "</ul></div>"
              
              $('#total-top-header .global-tabs').append(tab)
              $('#total-top-header .tab-content').append(links)
        else
            $('#total-top-header .no_user').removeClass('hidden')
      error: (data, textStatus, jqXHR) ->
        BikeIndex.alertMessage("error", "User load error", "We're sorry, we failed to load your user information. Try reloading maybe?")
      })

  initializeHeaderSearch: ->
    # Turn off autocomplete because it breaks things
    $("#head-search-bikes #query").attr("autocomplete","off");
    $('#search-nonstolen').click (e) ->
      e.preventDefault
      $('#search_stolen_').val('false')
      $('#head-search-bikes').submit()
    $('#search-stolen').click (e) ->
      e.preventDefault
      $('#search_stolen_').val('true')
      $('#head-search-bikes').submit()

  openNewWindow: (e) ->
    e.preventDefault()
    target = $(e.target)
    local = target.attr("data-target")
    if target.hasClass('same-window')
      window.location = local
    else
      window.open(local, '_blank')

  loadChosen: ->
    $('.chosen-select select').chosen()
  
  toggleCollapsibleHeader: ->
    # $('#header-tabs').css('min-height', '50px')
    $('#total-top-header').find('.search-background').toggleClass('show')
    $('#total-top-header').find('.background-extend').toggleClass('show')
    $('#total-top-header').find('.search-fields').toggleClass('show')
    $('#total-top-header').find('.global-tabs').toggleClass('show')
    $('#header').toggleClass('invisibled')
    $('#nav-header-collapse').toggleClass('expandable')
    # $('#header-tabs').collapse('toggle')
    # $('#header-tabs').css('height', 'auto')
    
    if $('#content-wrap').length > 0
      $('#content-wrap').toggleClass('header-closed')

  expandHeaderTab:(event) ->
    event.preventDefault()
    target = $(event.target)

    if target.parents('li').hasClass('active')
      $('#header-tabs .global-tabs li').removeClass('active')
      $('#header-tabs').removeClass('visibled')
    else
      if $('#header-tabs .tab-content').hasClass('visibled') 
        target.tab('show')
      else
        $('#header-tabs').addClass('visibled')
        target.tab('show')
      # Added this because sometimes the settings image makes things break.
      if target.parents('li').hasClass('settings')
        target.parents('li').find('a').tab('show')


  scrollToFootnote: (event) ->
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
      menu_height = menu.height() # + parseInt(tp, 10)
      b_offset = footer_offset - ( menu_height + 120 ) 
      
      $("<style>#content-menu.affix{top:#{b_offset}px};</style>").appendTo('head')
      # console.log($('#content-menu.affix').css('top'))
      # scroll_height = $(window).height() * .4
      # $('#body').attr('data-spy', "scroll").attr('data-target', '#edit-menu')
      # $('#body').scrollspy(offset: - scroll_height)
      # $('#clearing_span').css('height', $('#edit-menu').height() + 25)
      # $('#content-menu').affix(offset: {
      #   y: 100
      #   })
      $('#content-menu').attr('data-spy', 'affix').attr('data-offset-top', (b_offset))

      # $('#content-menu').attr('data-spy', 'affix').attr('data-offset-bottom', (700))

      # $('#content-menu').attr('data-spy', 'affix').attr('data-offset-top', (footer_height))