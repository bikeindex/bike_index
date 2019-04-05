class BikeIndex.RecoveryStories extends BikeIndex
  constructor: ->
    $('#recovery-stories-container').slick
      lazyLoad: 'ondemand'
      slidesToShow: $('#recovery_displays_count').val()
      vertical: true
