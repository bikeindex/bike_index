# Note: this is also loaded on info pages - because the recovery slider is included in get_your_stolen_bike_back
class BikeIndex.WelcomeIndex extends BikeIndex
  constructor: ->
    # Because of caching, manually update the active link
    @updateActiveLink()
    # Early exit if no recovery stories, ie on a news page without them
    return unless $('#recovery-stories-container').length
    @translator = new BikeIndex.GoogleTranslate()
    @container = $('#recovery-stories-container')
    @container.removeClass('extras-hidden')
    # NOTE: After fontawesome broke, switched to inline SVGs here
    @container.slick
      infinite: false
      lazyLoad: 'ondemand'
      prevArrow: '<span class="slick-prev"><svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="currentColor" class="bi bi-chevron-left" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0"/></svg></span>'
      nextArrow: '<span class="slick-next"><svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="currentColor" class="bi bi-chevron-right" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 .708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708"/></svg></span>'
      onBeforeChange: (slick, curr_i, target_i) =>
        @translateText(target_i)
      onInit: (slick) =>
        @translateText(0)

    $(window).scroll ->
      $('.root-landing-who').addClass('scrolled')

  updateActiveLink: ->
    if window.location.pathname.match("info/how-to-get-your-stolen-bike-back")
      $(".primary-nav-item .active").removeClass("active")
      $("#getStolenBackLink").addClass("active")

  # Return the DOM node for the slide with index `index` in the slides
  # container element.
  findSlide: (index) =>
    @container.find(".js-recovery-slide")[index]

  # Set or get the text of the slide.
  slideText: ($slide, textValue) =>
    $container = $slide.find(".precovery")
    return $container.text().trim() if not textValue
    $container.text(textValue)

  translateText: (index) =>
    return if I18n.locale == "en"

    slide = @findSlide(index)
    return unless slide

    $slide = $(slide)
    return if $slide.data("translated")

    text = @slideText($slide)

    @translator.translate(text).then (translatedText) =>
      return if not translatedText
      @slideText($slide, translatedText)
      $slide.data("translated", true)
      $slide.find(".translation-credit").toggleClass("d-none")
