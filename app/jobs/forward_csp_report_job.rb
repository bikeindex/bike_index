class ForwardCspReportJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 2

  HONEYBADGER_URL = "https://api.honeybadger.io/v1/browser/csp"
  HONEYBADGER_CSP_API_KEY = ENV["HONEYBADGER_CSP_API_KEY"]

  # The query is rebuilt here, not forwarded from the client, so the API key and
  # user context never ride in the browser-facing CSP report_uri.
  def perform(body, user_id, user_agent = nil)
    # dev/sandbox browsers still emit reports; only production forwards to Honeybadger
    return unless Rails.env.production? && HONEYBADGER_CSP_API_KEY.present?

    report = CspReport.parse(body)
    return if report.blank? || CspReport.noise?(report, user_agent)

    # Honeybadger records this request's user agent, which is Faraday - so the
    # browser's rides along as context, or a report can't be attributed at all
    query = URI.encode_www_form(api_key: HONEYBADGER_CSP_API_KEY, report_only: false,
      env: Rails.env, "context[user_id]": user_id.to_s,
      "context[user_agent]": user_agent.to_s)
    Faraday.post("#{HONEYBADGER_URL}?#{query}",
      {"csp-report" => CspReport.normalize(report)}.to_json,
      "Content-Type" => "application/csp-report")
  end
end
