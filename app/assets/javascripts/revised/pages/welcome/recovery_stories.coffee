class BikeIndex.RecoveryStories extends BikeIndex
  constructor: ->
    $recovery_stories = $('.recovery-stories-container')
    for recovery_story in $recovery_stories
        $recovery_story = $(recovery_story)
        $recovery_story.slick
          lazyLoad: 'ondemand'
          slidesToShow: $recovery_story.data('stories-count')
          vertical: true
