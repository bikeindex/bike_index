module ShortId
  extend Functionable

  # Type prefix for each object kind, so a short_id self-identifies
  PREFIXES = {bike: "r"}.freeze

  # Compact, type-prefixed alias for an id, e.g. ShortId.encode(:bike, 3431156) => "r/21J-HW"
  def encode(type, id)
    return if id.blank?

    "#{PREFIXES.fetch(type)}/#{id.to_s(36).upcase.scan(/.{1,3}/).join("-")}"
  end

  # Resolve a short_id back to an id. The type prefix and its separator are
  # both optional ("r/21J-HW", "r-21JHW", "r21jhw" all match), other separators
  # are ignored, and plain numeric ids pass through unchanged so existing
  # numeric URLs still work.
  def decode(type, short_id)
    prefix = /\A#{PREFIXES.fetch(type)}\W*/i
    prefixed = short_id.to_s.match?(prefix)
    str = short_id.to_s.sub(prefix, "").gsub(/\W/, "")
    (prefixed || str.match?(/[a-z]/i)) ? str.to_i(36) : str
  end
end
