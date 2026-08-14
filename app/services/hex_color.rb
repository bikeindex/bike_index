module HexColor
  extend Functionable

  # Lands in a style attribute, so nil unless it really is a hex
  def normalize(string)
    hex = digits(string)
    "##{hex}" if hex
  end

  # Through hsl, so taking a shade off a color of any hue is one number rather than three
  def darken_hex(string, amount: 0.08)
    hsl = darkened_hsl(string, amount:)
    return if hsl.nil?

    "##{rgb_from(*hsl).map { format("%02x", (it * 255).round) }.join}"
  end

  #
  # private below here
  #

  def darkened_hsl(string, amount:)
    hex = digits(string)
    return if hex.blank?

    rgb = channels(hex)
    min, max = rgb.minmax
    lightness = (max + min) / 2
    delta = max - min
    saturation = delta.zero? ? 0 : delta / (1 - ((2 * lightness) - 1).abs)
    [hue(*rgb, delta, max), saturation, [lightness - amount, 0].max]
  end

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
    sector * 60
  end

  def rgb_from(hue, saturation, lightness)
    chroma = (1 - ((2 * lightness) - 1).abs) * saturation
    second = chroma * (1 - (((hue / 60.0) % 2) - 1).abs)
    unshifted = case hue
    when 0...60 then [chroma, second, 0]
    when 60...120 then [second, chroma, 0]
    when 120...180 then [0, chroma, second]
    when 180...240 then [0, second, chroma]
    when 240...300 then [second, 0, chroma]
    else [chroma, 0, second]
    end
    unshifted.map { it + lightness - (chroma / 2) }
  end

  conceal :darkened_hsl, :digits, :channels, :hue, :rgb_from
end
