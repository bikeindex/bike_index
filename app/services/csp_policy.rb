# frozen_string_literal: true

# Whether our own Content Security Policy would have permitted a request.
module CspPolicy
  extend Functionable

  # Reads the global policy. No controller narrows it — news widens img_src and
  # strava_search sends no header — so a per-controller policy can only make this
  # answer too strict, never too permissive.
  def permits?(directive, uri)
    sources(directive).any? { |source| source_permits?(source, uri) }
  end

  #
  # private below here
  #

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

  conceal :sources, :source_permits?
end
