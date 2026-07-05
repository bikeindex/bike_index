module ShortId
  extend Functionable

  # Prefix per model class, so a short_id self-identifies
  PREFIXES = {"Bike" => "r", "BikeVersion" => "v", "MarketplaceListing" => "m"}.freeze

  # Compact, prefixed alias for an id, e.g. ShortId.encode("Bike", 3431156) => "r/21J-HW"
  def encode(class_name, id)
    return if id.blank?

    "#{PREFIXES.fetch(class_name)}/#{id.to_s(36).upcase.scan(/.{1,3}/).join("-")}"
  end

  # Resolve a short_id back to an id. The class prefix and its separator are
  # both optional ("r/21J-HW", "r-21JHW", "r21jhw" all match) and other
  # separators are ignored. A leftover with letters is base36; an all-digit
  # leftover is a plain decimal id, so "35", "r/35", and "z" all find bike 35.
  def decode(class_name, short_id)
    str = short_id.to_s.sub(/\A#{PREFIXES.fetch(class_name)}\W*/i, "").gsub(/\W/, "")
    str.match?(/[a-z]/i) ? str.to_i(36) : str
  end
end
