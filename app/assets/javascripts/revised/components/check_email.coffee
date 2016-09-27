class @CheckEmail # Use mailcheck to find emails with problems
  msg_selector =
    'email_check_message'
  constructor: (target_selector) ->
    $target = $(target_selector)
    @runMailcheck($target)
    @initializeMailCheck($target)

  initializeMailCheck: ($target) ->
    $target.on 'blur', (e) =>
      # Remove any existing warning
      $target.parents('.form-group').removeClass('has-warning')
      $("##{msg_selector}").slideUp 'fast', ->
        $("##{msg_selector}").remove()
      @runMailcheck($target)
      

  runMailcheck: ($target) ->
    Mailcheck.run
      email: $target.val()
      suggested: (result) =>
        $target.parents('.form-group').addClass('has-warning')
        msg = "Did you mean <ins>#{result.full}</ins> ?"
        $target.after("<div id='#{msg_selector}'>#{msg}</div>")
        $("##{msg_selector}").slideDown('fast')
        $("##{msg_selector}").on 'click', (e) =>
          # Replace the target's value with the message value
          $target.val($("##{msg_selector} ins").text())
          # remove the evidence
          $("##{msg_selector}").slideUp 'fast', ->
            $("##{msg_selector}").remove()
          $target.parents('.form-group').removeClass('has-warning')
