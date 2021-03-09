class BikeIndex.StolenBikeListing extends BikeIndex
  constructor: ->
    new BikeIndex.BikeSearchBar
    new BikeIndex.BikeBoxes
    # Expand the text on click
    $(".listing-text-expand-link").click (e) ->
      e.preventDefault()
      $target = $(e.target)
      $target.css("display", "none")
      $expander = $($target.attr("href"))
      $expander.slideDown 'fast', ->
        $expander.addClass("listing-text-shown")
        $expander.css("display", "inline-block")

    $(".listing-images a").click (e) ->
      e.preventDefault()
      $target = $(e.target)
      console.log($target.attr('href'))
      id = "#{$target.attr('id')}-modal"
      modal_html = "<div class='modal fade stolen-listing-photo-modal' id='#{id}'><div class='modal-dialog' role='document'><div class='modal-content'>"
      modal_html += "<div class='modal-title'><button class='close' 'aria-label'='Close' 'data-dismiss'='modal' type='button'><span 'aria-hidden'='true'>&times;</span></button></div>"
      modal_html += "<a href='#{$target.attr('href')}'><img src='#{$target.attr('href')}'></a>"
      modal_html += "</div></div></div>"
      $("#stolen_bike_listings_index").append(modal_html)
      $("##{id}").modal("show")

      $(window).on 'keyup', (e) ->
        $('.modal').modal('hide') if e.keyCode == 27 # Escape key
        return true
      # Remove keyup trigger, clean up after yourself
      $('.modal').on 'hide.bs.modal', ->
        $(window).off 'keyup'

