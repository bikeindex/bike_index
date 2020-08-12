class Phonifyer
  def self.phonify(string)
    return nil unless string.present?
    number = string.to_s.strip
    number, country_code = split_with_country_code(number)
    number, extension = split_with_extension(number)

    [
      country_code,
      strip_ignored_parts(number),
      extension
    ].compact.join(" ")
  end

  def self.strip_ignored_parts(number)
    return nil unless number.present?
    # Formatting bits that we don't care about
    number.gsub(/\s|\.|-|\(|\)|\//, "")
  end

  def self.split_with_country_code(number)
    return [number] unless number.start_with?(/\+/) # skip if it doesn't look like it has a country code!
    # grab the country_code
    country_code = number[/\A\+\d*/]
    if country_code.length > 10 # Looks like the whole number is in country code
      # This assumes the number is 10 digits long - so we grab any number before the last 10
      country_code = country_code.slice(0, (country_code.length - 10))
    end
    number = number.gsub(country_code, "")
    [number.strip, country_code.strip]
  end

  def self.split_with_extension(number)
    return [number] unless number.match?(/x/i)
    number, extension = number.split(/e?x[a-z]*/i)
    return [number, nil] unless extension.present?
    # Remove things we don't care about
    extension = extension.strip.gsub(/\A(-|\.|:)/, "")
    [number.strip, "x#{extension.strip}"]
  end

  def self.components(string)
    return nil unless string.present?
    number = string.to_s.strip
    number, country_code = split_with_country_code(number)
    number, extension = split_with_extension(number)

    {number: strip_ignored_parts(number)}.tap do |h|
      h[:country_code] = country_code.delete_prefix("+") if country_code.present?
      h[:extension] = extension.delete_prefix("x") if extension.present?
    end
  end
end
