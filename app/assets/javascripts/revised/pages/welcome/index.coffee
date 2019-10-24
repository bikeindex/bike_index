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
