class BikeIndex.WelcomeIndex extends BikeIndex
  constructor: ->
    @translator = new BikeIndex.GoogleTranslate()
    @container = $('#recovery-stories-container')
    @container.removeClass('extras-hidden')
    @container.slick
      infinite: false
      lazyLoad: 'ondemand'
      prevArrow: '<i class="fas fa-chevron-left slick-prev"></i>'
      nextArrow: '<i class="fas fa-chevron-right slick-next"></i>'
      onBeforeChange: (slick, curr_i, target_i) =>
        @translateText(target_i)
      onInit: (slick) =>
        @translateText(0)

    $(window).scroll ->
      $('.root-landing-who').addClass('scrolled')

   findSlide: (index) =>
     @container.find(".js-recovery-slide")[index]

   slideText: ($slide, textValue = null) =>
     if textValue == null
       $slide.find(".precovery").text().trim()
     else
       $slide.find(".precovery").text(textValue)

   translateText: (index) =>
     return if I18n.locale == "en"

     slide = @findSlide(index)
     return unless slide

     $slide = $(slide)
     return if $slide.data("translated")

     text = @slideText($slide)

     @translator.translate(text).then (translatedText) =>
       @slideText($slide, translatedText)
       $slide.data("translated", true)
