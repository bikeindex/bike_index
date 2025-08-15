module TurboMatchersHelper
  TURBO_VISIT = /Turbo\.visit\("([^"]+)", {"action":"([^"]+)"}\)/

  # Custom RSpec matcher for Turbo redirects
  RSpec::Matchers.define :redirect_to do |expected|
    match do |actual|
      if turbo_request?
        turbo_visit_to?(expected)
      else
        # Delegate to default redirect_to matcher
        super(expected)
      end
    end

    failure_message do |actual|
      if turbo_request?
        visit_location, _ = turbo_visit_location_and_action
        redirect_is = normalize_argument_to_redirection(visit_location)
        redirect_expected = normalize_argument_to_redirection(expected)
        "Expected response to be a Turbo visit to <#{redirect_expected}> but was a visit to <#{redirect_is}>"
      else
        # Use default failure message from redirect_to matcher
        super(expected)
      end
    end
  end

  # Helper method to check for Turbo visits
  def turbo_visit_to?(options)
    expect(response).to have_http_status(:ok)
    expect(response.media_type || response.content_type).to eq("text/javascript")

    visit_location, _ = turbo_visit_location_and_action
    redirect_is = normalize_argument_to_redirection(visit_location)
    redirect_expected = normalize_argument_to_redirection(options)

    redirect_expected === redirect_is
  end

  # Rough heuristic to detect whether this was a Turbolinks request:
  # non-GET request with a text/javascript response.
  #
  # Technically we'd check that Turbolinks-Referrer request header is
  # also set, but that'd require us to pass the header from post/patch/etc
  # test methods by overriding them to provide a `turbo:` option.
  #
  # We can't check `request.xhr?` here, either, since the X-Requested-With
  # header is cleared after controller action processing to prevent it
  # from leaking into subsequent requests.
  def turbo_request?
    !request.get? && (response.media_type || response.content_type) == "text/javascript"
  end

  def turbo_visit_location_and_action
    if response.body =~ TURBO_VISIT
      [$1, $2]
    end
  end

  # Assuming this is a Rails method that needs to be reimplemented
  def normalize_argument_to_redirection(arg)
    # For RSpec, you'd typically implement this based on your application's needs
    # This is a placeholder that should be customized based on how your app handles routes
    case arg
    when String
      arg
    when Hash
      arg.to_s # In a real app, you'd use url_for or other route helpers
    when Regexp
      arg
    else
      arg.to_s
    end
  end
end
