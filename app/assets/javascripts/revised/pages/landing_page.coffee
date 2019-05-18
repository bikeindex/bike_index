class BikeIndex.LandingPage extends BikeIndex
  constructor: ->
    $(".tryPaidButton").on "click", (e) =>
      e.preventDefault()
      plan = $(e.target).attr("data-plan")
      this.submitOrganizationPaidPlan(plan)
    $("#signup_package").on "change", (e) =>
      console.log $("#signup_package").val()
      $("#organizationSignupModal #body").val($("#signup_package").val())

    if $(window).width() > 767 # bootstrap md breakpoint
      # Instantiate stickyfill with offset of the header-nav
      header_offset = $('.primary-header-nav').outerHeight()
      $('.next-steps-wrap').css('top', "#{header_offset}px")
      # Affix the edit menu to the page
      $('.next-steps-wrap').Stickyfill()

  submitOrganizationPaidPlan: (plan) ->
    $("#organizationSignupModal").modal("show")
    if plan?
      $("#organizationSignupModal #feedback_body").val(plan)
      $("#organizationSignupModal .noplan").css("display", "none")
    else # There is no plan specified
      $("#organizationSignupModal .noplan").css("display", "block")

