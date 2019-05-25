class BikeIndex.LandingPage extends BikeIndex
  constructor: ->
    $(".tryPaidButton").on "click", (e) =>
      e.preventDefault()
      plan = $(e.target).attr("data-plan")
      this.submitOrganizationPaidPlan(plan)

    if $(window).width() > 767 # bootstrap md breakpoint
      # Instantiate stickyfill with offset of the header-nav
      header_offset = $('.primary-header-nav').outerHeight()
      $('.next-steps-wrap').css('top', "#{header_offset}px")
      # Affix the edit menu to the page
      $('.next-steps-wrap').Stickyfill()

  submitOrganizationPaidPlan: (plan) ->
    if plan?
      $("#organizationSignupModal #feedback_body").val(plan)
      $("#organizationSignupModal #feedback_package_size").val(plan)
    $("#organizationSignupModal").modal("show")

