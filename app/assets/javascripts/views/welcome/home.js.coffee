class BikeIndex.Views.Home extends Backbone.View
  # events:
  #   'click .play-button': 'movieShowtime'

  initialize: ->
    @setElement($('#body'))
    $(window).scroll ->
      $('#wheeled_wheel').addClass('spun')
      $(window).unbind('scroll')
      $('.bike-background').addClass('scrolled')
    h = $(window).height() - $('.wheel-holder').offset().top
    h = 400 if h > 400
    $('.wheel-holder').css('height', "#{h}px")
    # @spaceWheelHolder(true)
    $('.testimonial-container').slick
      infinite: false
      lazyLoad: 'ondemand'
      prevArrow: '<i class="fas fa-chevron-left slick-prev"></i>'
      nextArrow: '<i class="fas fa-chevron-right slick-next"></i>'

  spaceWheelHolder: (only_if_overlap=false) ->
    active_quote = $('.testimonial-block.active .testimonial-quote')
    b_quote = active_quote.offset().top + active_quote.outerHeight()
    t_wheel = $('.wheeled').offset().top
    wheel_margin = parseInt($('.wheeled').css('margin-top'))
    if only_if_overlap and b_quote < t_wheel
      return true
    else
      target = (b_quote - t_wheel) - 30
      # console.log(b_quote)
      # console.log(t_wheel)
      # console.log(b_quote - t_wheel)
      # console.log(wheel_margin)
      # console.log(target)
      $('.wheeled').css('margin-top', "#{target + wheel_margin}px")
