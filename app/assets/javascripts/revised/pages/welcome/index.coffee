class BikeIndex.WelcomeIndex extends BikeIndex
  constructor: ->
    $('#recovery-stories-container').removeClass('extras-hidden')
    $('#recovery-stories-container').slick
      infinite: false
      lazyLoad: 'ondemand'
      prevArrow: '<i class="fas fa-chevron-left slick-prev"></i>'
      nextArrow: '<i class="fas fa-chevron-right slick-next"></i>'
    $(window).scroll ->
      $('.root-landing-who').addClass('scrolled')
