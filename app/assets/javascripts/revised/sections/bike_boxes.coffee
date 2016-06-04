class BikeIndex.BikeBoxes extends BikeIndex
  constructor: ->
    @initializeHoverExpand()

  initializeHoverExpand: ->
    hoverExpand = @hoverExpand
    window.hoverExpandBlockTemplate = @hoverExpandBlockTemplate()
    Mustache.parse(window.hoverExpandBlockTemplate)

    $('a.hover-expand').hover (->
      $target = $(this)
      hoverExpand($target)
      $target.addClass 'img-expanded'
    ), ->
      $(this).removeClass 'img-expanded'

  hoverExpand: ($target) ->
    return true if $target.find('.hover-expand-block').length > 0
    # Manually replace the image url with src for medium images - brittle...
    # but we don't want to have to query every bikes public images
    data =
      title: $target.parents('.bike-box-item').find('.title-link').text() 
      img_src: $target.find('img').prop('src').replace /\/small_/, '/medium_'
    $target.append Mustache.to_html(window.hoverExpandBlockTemplate, data)

  hoverExpandBlockTemplate: ->
    """
      <div class="hover-expand-block">
        <img src="{{img_src}}">
        <p>{{title}}</p>
      </div>
    """