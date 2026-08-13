module HexColor
  extend Functionable

  # nil for anything else - this lands in a style attribute
  def normalize(string)
    hex = string.to_s.strip.delete_prefix("#").downcase
    "##{hex}" if hex.match?(/\A(\h{3}|\h{6})\z/)
  end
end
