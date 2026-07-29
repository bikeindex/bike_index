class ForwardCspReportJob < ApplicationJob
  sidekiq_options queue: "low_priority", retry: 2

  HONEYBADGER_URL = "https://api.honeybadger.io/v1/browser/csp"
  HONEYBADGER_CSP_API_KEY = ENV["HONEYBADGER_CSP_API_KEY"]
  EXTENSION_SCHEME = %r{\A(chrome|moz|safari|safari-web)-extension://}
  IN_APP_BROWSER = /\b(FBAN|FBAV|FB_IAB|Instagram|Line\/)\b/
  TRANSLATE_DOCUMENT = /\.translate\.goog\z|translate\.google(apis)?\.com/
  # Google Ads conversion iframes load on country-specific google.<tld> domains;
  # CSP frame_src allowlists common ones, we silence reports for the rest. Frame
  # violations report the bare origin, hence the trailing slash-or-end.
  GOOGLE_FRAME = %r{\Ahttps://www\.google\.[a-z.]+(/|\z)}
  # Corporate proxies, antivirus, and carriers inject frames pointing at private
  # or loopback IPs — the user's own network, nothing we serve or can fix.
  PRIVATE_IP_FRAME = %r{\Ahttps?://(10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)}

  # The query is rebuilt here, not forwarded from the client, so the API key and
  # user context never ride in the browser-facing CSP report_uri.
  def perform(body, user_id, user_agent = nil)
    # dev/sandbox browsers still emit reports; only production forwards to Honeybadger
    return unless Rails.env.production? && HONEYBADGER_CSP_API_KEY.present?

    report = parsed_report(body)
    return unless forward?(report, user_agent)

    query = URI.encode_www_form(api_key: HONEYBADGER_CSP_API_KEY, report_only: false,
      env: Rails.env, "context[user_id]": user_id.to_s)
    Faraday.post("#{HONEYBADGER_URL}?#{query}", body, "Content-Type" => "application/csp-report")
  end

  private

  def parsed_report(body)
    parsed = JSON.parse(body)
    parsed["csp-report"] if parsed.is_a?(Hash) && parsed["csp-report"].is_a?(Hash)
  rescue JSON::ParserError, TypeError
    nil
  end

  def forward?(report, user_agent)
    report.present? && !user_agent.to_s.match?(IN_APP_BROWSER) &&
      !extension_noise?(report) && !translate_noise?(report) &&
      !google_frame_noise?(report) && !private_ip_noise?(report)
  end

  def extension_noise?(report)
    [report["blocked-uri"], report["source-file"]].compact
      .any? { |uri| uri.match?(EXTENSION_SCHEME) }
  end

  # Google Translate reskins the page and injects read-aloud TTS audio as data: media
  def translate_noise?(report)
    return true if report["document-uri"].to_s.match?(TRANSLATE_DOCUMENT)
    report["effective-directive"] == "media-src" && report["blocked-uri"].to_s == "data"
  end

  def google_frame_noise?(report)
    report["blocked-uri"].to_s.match?(GOOGLE_FRAME)
  end

  def private_ip_noise?(report)
    report["blocked-uri"].to_s.match?(PRIVATE_IP_FRAME)
  end
end
