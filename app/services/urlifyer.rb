module Urlifyer
  extend Functionable

  # A dotted hostname, without spaces. Also a pattern attribute, which takes no flags - so no /i
  WEBSITE_REGEX = %r{\A([a-zA-Z]+://)?[^\s\/]+\.[a-zA-Z]{2,}(/\S*)?\z} # rubocop:disable Style/RedundantRegexpEscape -- the v flag needs them

  # This is sketchy, it can fail and not tell anyone anything
  # but if we don't put in http:// when people enter input, it won't link correctly.
  # TODO: Improve this, add errors or something

  def urlify(string)
    return nil unless string.present? && string.length > 1
    return string if string.match(/\Ahttp.?:\/\//i).present?

    "http://#{string.strip}"
  end

  # The address without its scheme or www, for the text of a link
  def display(string, length: nil)
    return nil if string.blank?

    address = string.strip.sub(%r{\Ahttps?://(www\.)?}i, "")
    length ? address.truncate(length) : address
  end

  def uri?(string)
    uri = URI.parse(string)
    %w[http https].include?(uri.scheme)
  rescue URI::BadURIError
    false
  rescue URI::InvalidURIError
    false
  end
end
