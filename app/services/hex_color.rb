module HexColor
  extend Functionable

  # Lands in a style attribute, so nil unless it really is a hex
  def normalize(string)
    hex = digits(string)
    "##{hex}" if hex
  end

  # hsla, so taking a shade off a color of any hue is one number rather than three
  def darken(string, amount: 0.08)
    hex = digits(string)
    return if hex.blank?

    rgb = channels(hex)
    min, max = rgb.minmax
    lightness = (max + min) / 2
    delta = max - min
    saturation = delta.zero? ? 0 : delta / (1 - ((2 * lightness) - 1).abs)
    "hsla(#{hue(*rgb, delta, max)}, #{percent(saturation)}, #{percent([lightness - amount, 0].max)}, 1)"
  end

  #
  # private below here
  #

  def digits(string)
    return if string.blank?

    hex = string.to_s.strip.delete_prefix("#").downcase
    hex if hex.match?(/\A(\h{3}|\h{6})\z/)
  end

  def channels(hex)
    chunks = (hex.length == 3) ? hex.chars.map { it * 2 } : hex.scan(/../)
    chunks.map { it.to_i(16) / 255.0 }
  end

  def hue(red, green, blue, delta, max)
    return 0 if delta.zero?

    sector = case max
    when red then ((green - blue) / delta) % 6
    when green then ((blue - red) / delta) + 2
    else ((red - green) / delta) + 4
    end
    (sector * 60).round
  end

  def percent(fraction) = "#{(fraction * 100).round}%"

  conceal :digits, :channels, :hue, :percent
end
