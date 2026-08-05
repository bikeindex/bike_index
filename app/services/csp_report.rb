# frozen_string_literal: true

# Parses a browser CSP report and decides whether it describes something we can
# act on. CspPolicy answers what our own policy permits; this decides what's
# worth forwarding, and normalizes what is.
module CspReport
  extend Functionable

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
  BLOCKED_URI_NOISE = Regexp.union(GOOGLE_FRAME, PRIVATE_IP_FRAME)

  def parse(body)
    parsed = JSON.parse(body)
    parsed["csp-report"] if parsed.is_a?(Hash) && parsed["csp-report"].is_a?(Hash)
  rescue JSON::ParserError, TypeError
    nil
  end

  def noise?(report, user_agent = nil)
    user_agent.to_s.match?(IN_APP_BROWSER) || extension_noise?(report) ||
      translate_noise?(report) || report["blocked-uri"].to_s.match?(BLOCKED_URI_NOISE) ||
      third_party_font_noise?(report) || foreign_policy_noise?(report)
  end

  # Honeybadger fingerprints a fault on the whole blocked-uri, so a query string
  # that varies per request mints a new fault every time — one ad conversion url
  # accounted for hundreds of them.
  def normalize(report)
    uri = parsed_uri(report["blocked-uri"])
    return report if uri.nil?

    report.merge("blocked-uri" => "#{uri.scheme}://#{uri.host}#{uri.path}")
  end

  #
  # private below here
  #

  def extension_noise?(report)
    [report["blocked-uri"], report["source-file"]].compact
      .any? { |uri| uri.match?(EXTENSION_SCHEME) }
  end

  # Google Translate reskins the page and injects read-aloud TTS audio as data: media
  def translate_noise?(report)
    return true if report["document-uri"].to_s.match?(TRANSLATE_DOCUMENT)
    report["effective-directive"] == "media-src" && report["blocked-uri"].to_s == "data"
  end

  # An extension that tightens our response header still reports to our report-uri,
  # so a cross-origin block our own policy would have permitted wasn't ours. Same
  # origin is exempt: 'self' always permits it, and what the browser is actually
  # reporting is a redirect to a target it won't name.
  def foreign_policy_noise?(report)
    uri = cross_origin_blocked_uri(report)
    uri && CspPolicy.permits?(directive(report), uri)
  end

  # Every font we load is on our own origin or in font_src, so a font blocked from
  # a third party was injected into the page — coupon and citation extensions add
  # page-level <link>s, which carry an https uri EXTENSION_SCHEME can't recognize.
  # The cost is that a webfont host we forget to allowlist goes unreported.
  def third_party_font_noise?(report)
    directive(report) == "font-src" && cross_origin_blocked_uri(report).present?
  end

  # Old browsers send the sources along with the name: "font-src https://x"
  def directive(report)
    (report["effective-directive"].presence || report["violated-directive"]).to_s.split.first
  end

  def cross_origin_blocked_uri(report)
    uri = parsed_uri(report["blocked-uri"])
    uri if uri && uri.host != parsed_uri(report["document-uri"])&.host
  end

  def parsed_uri(value)
    uri = URI.parse(value.to_s)
    uri if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  conceal :extension_noise?, :translate_noise?, :foreign_policy_noise?,
    :third_party_font_noise?, :directive, :cross_origin_blocked_uri, :parsed_uri
end
