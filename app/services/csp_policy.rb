# frozen_string_literal: true

# Whether our own Content Security Policy would have permitted a request.
module CspPolicy
  extend Functionable

  # A directive we don't declare is enforced by the first of these we do.
  # default-src terminates every chain, so it isn't listed.
  DIRECTIVE_FALLBACKS = {
    "script-src-elem" => "script-src",
    "script-src-attr" => "script-src",
    "style-src-elem" => "style-src",
    "style-src-attr" => "style-src",
    "worker-src" => "script-src"
  }.freeze

  # Reads the global policy. No controller narrows it — news widens img_src and
  # strava_search sends no header — so a per-controller policy can only make this
  # answer too strict, never too permissive.
  def permits?(directive, uri)
    sources(directive).any? { |source| source_permits?(source, uri) }
  end

  #
  # private below here
  #

  def sources(directive)
    directives = Rails.application.config.content_security_policy&.directives || {}
    [directive, DIRECTIVE_FALLBACKS[directive], "default-src"]
      .filter_map { |name| directives[name] }.first || []
  end

  def source_permits?(source, uri)
    return false if source.start_with?("'") # 'self' and 'unsafe-*' name no host
    return uri.scheme == source.chomp(":") if source.end_with?(":") # data:, blob:

    scheme, _, host = source.rpartition("//") # a bare host has no scheme to check
    return false if scheme.present? && scheme.chomp(":") != uri.scheme

    host_permits?(host, uri.host)
  end

  # A leading *. matches subdomains only, never the bare domain
  def host_permits?(source_host, host)
    return host == source_host unless source_host.start_with?("*.")

    host.end_with?(source_host.delete_prefix("*"))
  end

  conceal :sources, :source_permits?, :host_permits?
end
