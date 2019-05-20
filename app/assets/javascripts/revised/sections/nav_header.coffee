class BikeIndex.NavHeader extends BikeIndex
  headroomOptions:
    offset: 48

  constructor: ->
    @initializeHamburgler()
    # Instantiate headroom - scroll to hide header
    $('nav.primary-header-nav').headroom(@headroomOptions)

    # TODO: fix when new bootstrap applied - right now, on iphone, clicking doesn't always work,
    # we're trying to catch it here
    if $(window).width() < 768
      $(".current-organization-submenu").click (e) =>
        $target = $(event.target)
        if $target.attr("href")
          window.location = $target.attr("href")

  initializeHamburgler: ->
    # toggleMenu = @toggleMenu
    $('.hamburgler').click (e) =>
      e.preventDefault()
      $('.hamburgler a').toggleClass('active') # prevent hamburglar flicker back and forth
      @toggleMenu($('nav.primary-header-nav').hasClass('menu-in') )

    $('#menu-opened-backdrop').click (e) =>
      @toggleMenu(true)

  toggleMenu: (is_open = false)->
    if is_open
      $('.hamburgler a').removeClass('active')
      $('nav.primary-header-nav')
        .removeClass('menu-in')
        .headroom(@headroomOptions)
      $('body').removeClass('menu-in')

      # $mainmenu-transform-speed in primary_header_nav.scss
      # So that it hides it if it should be hidden, even on opera mini
      # But still animates
      setTimeout (->
        $('nav.primary-header-nav').removeClass('enabled')
      ), 200
    else
      $('nav.primary-header-nav').addClass('enabled')
      $('.hamburgler a').addClass('active')
      setTimeout (->
        $('nav.primary-header-nav')
          .addClass('menu-in')
          .headroom('destroy')
          .removeData('headroom')
        $('body').addClass('menu-in')
      ), 50 # So that it animates...
