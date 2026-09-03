# frozen_string_literal: true

# Parses a browser CSP report, decides whether it describes something we can act
# on, and normalizes what it does.
module CspReport
  extend Functionable

  EXTENSION_SCHEME = %r{\A(chrome|moz|safari|safari-web)-extension://}
  IN_APP_BROWSER = /\b(FBAN|FBAV|FB_IAB|Instagram|Line\/)\b/
  TRANSLATE_DOCUMENT = /\.translate\.goog\z|translate\.google(apis)?\.com/
  BLOCKED_URI_NOISE = Regexp.union(
    # Google Ads conversion iframes load on country-specific google.<tld> domains;
    # CSP frame_src allowlists common ones, we silence reports for the rest. Frame
    # violations report the bare origin, hence the trailing slash-or-end.
    %r{\Ahttps://www\.google\.[a-z.]+(/|\z)},
    # Corporate proxies, antivirus, and carriers inject frames pointing at private
    # or loopback IPs — the user's own network, nothing we serve or can fix.
    %r{\Ahttps?://(10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)}
  )

  def parse(body)
    parsed = JSON.parse(body)
    parsed["csp-report"] if parsed.is_a?(Hash) && parsed["csp-report"].is_a?(Hash)
  rescue JSON::ParserError, TypeError
    nil
  end

  def noise?(report, user_agent)
    user_agent.to_s.match?(IN_APP_BROWSER) || extension_noise?(report) ||
      translate_noise?(report) || report["blocked-uri"].to_s.match?(BLOCKED_URI_NOISE) ||
      cross_origin_noise?(report)
  end

  # Honeybadger fingerprints a fault on the whole blocked-uri, so a query string
  # that varies per request mints a new fault every time — one ad conversion url
  # accounted for hundreds of them.
  def normalize(report)
    uri = parsed_uri(report["blocked-uri"])
    return report if uri.nil?

    uri.query = nil
    uri.fragment = nil
    report.merge("blocked-uri" => uri.to_s)
  end

  #
  # private below here
  #

  # Whether our own Content Security Policy would have permitted a request. Only
  # meaningful for a cross-origin uri — quoted sources name no host, so a same
  # origin uri 'self' plainly allows still answers false.
  #
  # Reads the global policy. No controller narrows it — news widens img_src and
  # strava_search sends no header — so a per-controller policy can only make this
  # answer too strict, never too permissive.
  def permits?(directive, uri)
    sources(directive).any? { |source| source_permits?(source, uri) }
  end

  # An undeclared directive is enforced by the first one we do declare: an
  # -elem/-attr variant falls back to its base, and anything else to default-src.
  def sources(directive)
    directives = Rails.application.config.content_security_policy&.directives || {}
    directives[directive] || directives[directive.to_s.sub(/-(elem|attr)\z/, "")] ||
      directives["default-src"] || []
  end

  def source_permits?(source, uri)
    return false if source.start_with?("'") # 'self' and 'unsafe-*' name no host
    return uri.scheme == source.chomp(":") if source.end_with?(":") # data:, blob:

    scheme, _, host = source.rpartition("//") # a bare host has no scheme to check
    return false if scheme.present? && scheme.chomp(":") != uri.scheme
    # A leading *. matches subdomains only, never the bare domain
    return uri.host.end_with?(host.delete_prefix("*")) if host.start_with?("*.")

    uri.host == host
  end

  def extension_noise?(report)
    [report["blocked-uri"], report["source-file"]].compact
      .any? { |uri| uri.match?(EXTENSION_SCHEME) }
  end

  # Google Translate reskins the page and injects read-aloud TTS audio as data: media
  def translate_noise?(report)
    return true if report["document-uri"].to_s.match?(TRANSLATE_DOCUMENT)
    directive(report) == "media-src" && report["blocked-uri"].to_s == "data"
  end

  # Same origin is exempt: 'self' always permits it, and what the browser is
  # actually reporting is a redirect to a target it won't name.
  def cross_origin_noise?(report)
    uri = cross_origin_blocked_uri(report)
    return false if uri.nil?

    # Every font we load is on our own origin or in font_src, so a font blocked from
    # a third party was injected into the page — coupon and citation extensions add
    # page-level <link>s, which carry an https uri EXTENSION_SCHEME can't recognize.
    # The cost is that a webfont host we forget to allowlist goes unreported.
    return true if directive(report) == "font-src"

    # An extension that tightens our response header still reports to our
    # report-uri, so a block our own policy would have permitted wasn't ours.
    permits?(directive(report), uri)
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

  conceal :permits?, :sources, :source_permits?, :extension_noise?,
    :translate_noise?, :cross_origin_noise?, :directive,
    :cross_origin_blocked_uri, :parsed_uri
end
