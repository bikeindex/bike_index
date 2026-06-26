module ShortId
  extend Functionable

  # Compact alphanumeric alias for an id, usable in /bikes/:id URLs
  def encode(id)
    id&.to_s(36)&.upcase
  end

  # Resolve a param that may be a numeric id or a base36 short_id.
  # Plain-digit params stay decimal ids, so existing numeric URLs are unchanged.
  def decode(param)
    param = param.to_s
    param.match?(/[a-z]/i) ? param.to_i(36) : param
  end
end
