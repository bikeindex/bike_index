class ForwardCspReportJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 2

  HONEYBADGER_URL = "https://api.honeybadger.io/v1/browser/csp"

  # The query is rebuilt here, not forwarded from the client, so the API key and
  # user context never ride in the browser-facing CSP report_uri.
  def perform(body, user_id)
    api_key = ENV["HONEYBADGER_CSP_API_KEY"]
    return if api_key.blank?

    query = URI.encode_www_form(api_key:, report_only: false,
      env: Rails.env, "context[user_id]": user_id.to_s)
    Faraday.post("#{HONEYBADGER_URL}?#{query}", body, "Content-Type" => "application/csp-report")
  end
end
