# Receives browser CSP violation reports, drops known noise (browser extensions,
# in-app browsers, translate proxies), and forwards the rest to Honeybadger.
class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token

  EXTENSION_SCHEME = %r{\A(chrome|moz|safari|safari-web)-extension://}
  IN_APP_BROWSER = /\b(FBAN|FBAV|FB_IAB|Instagram|Line\/)\b/
  TRANSLATE_DOCUMENT = /\.translate\.goog\z|translate\.google(apis)?\.com/

  def create
    report = parsed_report
    if report.present? && !ignorable?(report)
      ForwardCspReportJob.perform_async(request.raw_post, request.query_string)
    end
    head :no_content
  end

  private

  def parsed_report
    JSON.parse(request.raw_post).then { |h| h["csp-report"] if h.is_a?(Hash) && h["csp-report"].is_a?(Hash) }
  rescue JSON::ParserError, TypeError
    nil
  end

  def ignorable?(report)
    extension_noise?(report) || in_app_browser? || translate_noise?(report)
  end

  def extension_noise?(report)
    [report["blocked-uri"], report["source-file"]].compact
      .any? { |uri| uri.match?(EXTENSION_SCHEME) }
  end

  def in_app_browser?
    request.user_agent.to_s.match?(IN_APP_BROWSER)
  end

  # Google Translate reskins the page and injects google.<tld> frames + read-aloud TTS audio
  def translate_noise?(report)
    blocked = report["blocked-uri"].to_s
    return true if report["document-uri"].to_s.match?(TRANSLATE_DOCUMENT)
    return true if blocked.match?(%r{\Ahttps://www\.google\.[a-z.]+/})

    report["effective-directive"] == "media-src" && blocked == "data"
  end
end
