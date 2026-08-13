module HexColor
  extend Functionable

  # nil for anything else - this lands in a style attribute
  def normalize(string)
    hex = string.to_s.strip.delete_prefix("#").downcase
    "##{hex}" if hex.match?(/\A(\h{3}|\h{6})\z/)
  end

  # hsla, so taking a shade off a color of any hue is one number rather than three
  def darken(string, amount: 0.08)
    hex = normalize(string)
    return if hex.blank?

    red, green, blue = channels(hex)
    max, min = [red, green, blue].minmax.reverse
    lightness = (max + min) / 2
    delta = max - min
    saturation = delta.zero? ? 0 : delta / (1 - ((2 * lightness) - 1).abs)
    "hsla(#{hue(red, green, blue, delta).round}, #{percent(saturation)}, #{percent([lightness - amount, 0].max)}, 1)"
  end

  #
  # private below here
  #

  def channels(hex)
    digits = hex.delete_prefix("#")
    digits = digits.chars.flat_map { [it, it] }.join if digits.length == 3
    digits.scan(/../).map { it.to_i(16) / 255.0 }
  end

  def hue(red, green, blue, delta)
    return 0 if delta.zero?

    sector = case [red, green, blue].max
    when red then ((green - blue) / delta) % 6
    when green then ((blue - red) / delta) + 2
    else ((red - green) / delta) + 4
    end
    sector * 60
  end

  def percent(fraction) = "#{(fraction * 100).round}%"

  conceal :channels, :hue, :percent
end
