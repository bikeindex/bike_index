class ForwardCspReportJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 2

  HONEYBADGER_URL = "https://api.honeybadger.io/v1/browser/csp"

  def perform(body, query_string)
    return if ENV["HONEYBADGER_CSP_API_KEY"].blank?

    url = query_string.present? ? "#{HONEYBADGER_URL}?#{query_string}" : HONEYBADGER_URL
    Faraday.post(url, body, "Content-Type" => "application/csp-report")
  end
end
