class BikeIndex.Organized extends BikeIndex
  constructor: ->
    @setOrganizedWrapHeight()

    # Only on the edit organization page, but no real reason to create another
    # coffeescript file
    $('.avatar-upload-field').change (event) ->
      name = event.target.files[0].name
      $(event.target).parent().find('.file-upload-text').text(name)

    # On the stickers#index page, submit search after update
    # click rather than change b/c this version of bootstrap blocks bubbling up change events from btn-groups :/
    $("#organized-bike-code-claimedness .btn").on "click", (event) ->
       window.setTimeout (->
        $(".stickers-form").submit()
       ), 250

    # This is copied and adapted from binx_admin.js, we need to switch to es6 :(
    $('#timeSelectionBtnGroup button').on 'click', (e) ->
      period = $(e.target).attr('data-period')
      current_url = location.href.replace(/&?period=[^&]*/, '')
      if current_url.match(/\?/)
        joiner = '&'
      else
        joiner = '?'

      location.href = "#{current_url}#{joiner}period=#{period}"

  setOrganizedWrapHeight: ->
    min_px = $('.organized-menu-wrapper').outerHeight()
    $('.organized-wrap').css('min-height', "#{min_px + 24}px")
