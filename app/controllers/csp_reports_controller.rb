# Receives browser CSP violation reports, drops known noise (browser extensions,
# in-app browsers, translate proxies), and forwards the rest to Honeybadger.
class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token

  EXTENSION_SCHEME = %r{\A(chrome|moz|safari|safari-web)-extension://}
  IN_APP_BROWSER = /\b(FBAN|FBAV|FB_IAB|Instagram|Line\/)\b/
  TRANSLATE_DOCUMENT = /\.translate\.goog\z|translate\.google(apis)?\.com/
  # Corporate proxies, antivirus, and carriers inject frames pointing at private
  # or loopback IPs — the user's own network, nothing we serve or can fix.
  PRIVATE_IP_FRAME = %r{\Ahttps?://(10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)}

  def create
    # Browsers/bots occasionally send malformed byte sequences (e.g. overlong
    # UTF-8) that raise downstream, both from Regexp#match? and from Sidekiq's
    # JSON-encoding of the job args, so scrub once at the boundary.
    body = request.raw_post.dup.force_encoding(Encoding::UTF_8).scrub
    report = parsed_report(body)
    ForwardCspReportJob.perform_async(body, current_user&.id) if send_report?(report)
    head :no_content
  end

  private

  def parsed_report(body)
    parsed = JSON.parse(body)
    parsed["csp-report"] if parsed.is_a?(Hash) && parsed["csp-report"].is_a?(Hash)
  rescue JSON::ParserError, TypeError
    nil
  end

  def send_report?(report)
    report.present? && !request.user_agent.to_s.match?(IN_APP_BROWSER) &&
      !extension_noise?(report) && !translate_noise?(report) && !private_ip_noise?(report)
  end

  def private_ip_noise?(report)
    report["blocked-uri"].to_s.match?(PRIVATE_IP_FRAME)
  end

  def extension_noise?(report)
    [report["blocked-uri"], report["source-file"]].compact
      .any? { |uri| uri.match?(EXTENSION_SCHEME) }
  end

  # Google Translate reskins the page and injects google.<tld> frames + read-aloud TTS audio
  def translate_noise?(report)
    blocked = report["blocked-uri"].to_s
    return true if report["document-uri"].to_s.match?(TRANSLATE_DOCUMENT)
    # Frame violations report the bare origin (no path), so match a trailing slash or end
    return true if blocked.match?(%r{\Ahttps://www\.google\.[a-z.]+(/|\z)})

    report["effective-directive"] == "media-src" && blocked == "data"
  end
end
