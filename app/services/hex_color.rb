module HexColor
  extend Functionable

  # Anything that isn't a hex color is nothing, since this goes into a style attribute
  def normalize(string)
    hex = string.to_s.strip.delete_prefix("#").downcase
    "##{hex}" if hex.match?(/\A(\h{3}|\h{6})\z/)
  end
end
