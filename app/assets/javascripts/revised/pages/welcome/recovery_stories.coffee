class BikeIndex.RecoveryStories extends BikeIndex
  constructor: ->
    $recovery_stories = $('#recovery-stories-container')
    $recovery_stories.slick
      lazyLoad: 'ondemand'
      slidesToShow: $recovery_stories.data('stories-count')
      vertical: true
