class BikeIndex.NavHeader extends BikeIndex
  constructor: ->
    @initializeHamburgler()

    # Some small screen specific things
    if $(window).width() < 768
      # TODO: fix when new bootstrap applied - right now, on iphone, clicking doesn't always work,
      # we're trying to catch it here
      $(".current-organization-submenu").click (e) =>
        $target = $(event.target)
        if $target.attr("href")
          window.location = $target.attr("href")

      # If the passive_organization name is too wide, it overflows and makes the topbar hide things
      # So truncate it
      available_width = $(".primary-header-nav .container").innerWidth() -
        $(".primary-header-nav .primary-logo").outerWidth() -
        $(".primary-header-nav .hamburgler").outerWidth()
      # There is also a 16px margin and a bunch of padding on either side on current-organization-submenu, so subtract that as well
      $("#passive_organization_submenu").css("max-width", "#{available_width - 102}px")

  # The menu and its backdrop are fixed to the viewport, but the navbar isn't -
  # the review-app banner pushes it down, further still when the PR title wraps.
  # So sit them below wherever the hamburgler actually ends, rather than assuming
  positionMainMenu: ->
    $hamburgler = $(".primary-header-nav .hamburgler")
    return unless $hamburgler.is(":visible")
    top = $hamburgler[0].getBoundingClientRect().bottom
    $(".primary-main-menu, #menu-opened-backdrop").css("top", "#{top}px")

  initializeHamburgler: ->
    # Add character for displaying the hamburger - doing it here so it isn't rendered for lynx :/
    $("#primary_nav_hamburgler").html("&#9776;")
    $('.hamburgler').click (e) =>
      e.preventDefault()
      $('#primary_nav_hamburgler').toggleClass('active') # prevent hamburglar flicker back and forth
      @toggleMenu($('nav.primary-header-nav').hasClass('menu-in') )

    $('#menu-opened-backdrop').click (e) =>
      @toggleMenu(true)

    # Rotating or resizing with the menu open changes how tall the banner is
    $(window).resize =>
      @positionMainMenu() if $('nav.primary-header-nav').hasClass('menu-in')

    $(document).keyup (e) =>
      return unless e.key == 'Escape' && $('nav.primary-header-nav').hasClass('menu-in')
      @toggleMenu(true)
      $('#primary_nav_hamburgler').focus()

  toggleMenu: (is_open = false)->
    $('#primary_nav_hamburgler').attr('aria-expanded', "#{!is_open}")
    if is_open
      $('#primary_nav_hamburgler').removeClass('active')
      $('nav.primary-header-nav').removeClass('menu-in')
      $('body').removeClass('menu-in')

      # $mainmenu-transform-speed in primary_header_nav.scss
      # So that it hides it if it should be hidden, even on opera mini
      # But still animates
      setTimeout (->
        $('nav.primary-header-nav').removeClass('enabled')
      ), 200
    else
      @positionMainMenu()
      $('nav.primary-header-nav').addClass('enabled')
      $('#primary_nav_hamburgler').addClass('active')
      setTimeout (->
        $('nav.primary-header-nav').addClass('menu-in')
        $('body').addClass('menu-in')
      ), 50 # So that it animates...
