class BikeIndex.NavHeader extends BikeIndex
  headroomOptions: 
    offset: 48

  constructor: ->
    @initializeHamburgler()
    # Instantiate headroom - scroll to hide header
    $('nav.primary-header-nav').headroom(@headroomOptions)

  initializeHamburgler: ->
    # toggleMenu = @toggleMenu
    $('.hamburgler').click (e) =>
      e.preventDefault()
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
