# Receives browser CSP violation reports, drops known noise (browser extensions,
# in-app browsers, translate proxies), and forwards the rest to Honeybadger.
class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token

  EXTENSION_SCHEME = %r{\A(chrome|moz|safari|safari-web)-extension://}
  IN_APP_BROWSER = /\b(FBAN|FBAV|FB_IAB|Instagram|Line\/)\b/
  TRANSLATE_DOCUMENT = /\.translate\.goog\z|translate\.google(apis)?\.com/

  def create
    report = parsed_report(request.raw_post)
    ForwardCspReportJob.perform_async(request.raw_post, current_user&.id) if send_report?(report)
    head :no_content
  end

  private

  def parsed_report(raw_post)
    parsed = JSON.parse(raw_post)
    parsed["csp-report"] if parsed.is_a?(Hash) && parsed["csp-report"].is_a?(Hash)
  rescue JSON::ParserError, TypeError
    nil
  end

  def send_report?(report)
    report.present? && !request.user_agent.to_s.match?(IN_APP_BROWSER) &&
      !extension_noise?(report) && !translate_noise?(report)
  end

  def extension_noise?(report)
    [report["blocked-uri"], report["source-file"]].compact
      .any? { |uri| uri.match?(EXTENSION_SCHEME) }
  end

  # Google Translate reskins the page and injects google.<tld> frames + read-aloud TTS audio
  def translate_noise?(report)
    blocked = report["blocked-uri"].to_s
    return true if report["document-uri"].to_s.match?(TRANSLATE_DOCUMENT)
    return true if blocked.match?(%r{\Ahttps://www\.google\.[a-z.]+/})

    report["effective-directive"] == "media-src" && blocked == "data"
  end
end
