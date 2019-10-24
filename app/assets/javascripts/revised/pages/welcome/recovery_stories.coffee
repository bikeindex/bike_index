class BikeIndex.WelcomeRecoveryStories extends BikeIndex
  constructor: (container) ->
    @translator = new BikeIndex.GoogleTranslate()
    @$slides = $("#recovery-stories-listing").find(".js-recovery-slide")
    @translateText()

   translateText: (index) =>
     return if I18n.locale == "en"

     @$slides.each (i, slide) =>
      $slide = $(slide)
      return if $slide.data("translated")

      text = @slideText($slide)

      @translator.translate(text).then (translatedText) =>
        return if not translatedText
        @slideText($slide, translatedText)
        $slide.data("translated", true)

   # Set or get the text of the slide.
   slideText: ($slide, textValue) =>
     $container = $slide.find(".precovery")
     return $container.text().trim() if not textValue
     $container.text(textValue)
