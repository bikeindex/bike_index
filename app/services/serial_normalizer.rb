class SerialNormalizer
  SUBSTITUTIONS = {
    "|IL" => "1",
    "O" => "0",
    "S" => "5",
    "Z" => "2",
    "B" => "8"
  }.freeze

  UNKNOWN_STRINGS = ["na", "idk", "no", "unkown", "no serial", "none", "tbd"].freeze

  def self.unknown_and_absent_corrected(str = nil)
    str = str.to_s.strip
    # Return unknown if blank, '?' or 'absent' (legacy concern - 'unknown' used to be stored as 'absent')
    return "unknown" if str.blank? || str.gsub(/\s|\?/, "").blank? || str.downcase == "absent"
    return "made_without_serial" if str == "made_without_serial" || looks_like_made_without?(str)
    return "unknown" if looks_like_unknown?(str.downcase)
    str.gsub(/\s+/, " ")
  end

  def self.looks_like_made_without?(str)
    str_downcase = str.downcase
    [/custom/, /made.without.serial/].any? { |r| r.match?(str_downcase) }
  end

  def self.looks_like_unknown?(str_downcase)
    return true if UNKNOWN_STRINGS.include?(str_downcase) # specific things
    if str_downcase[/(no)|(remember)/].present?
      return true if str_downcase[/unkno/].present?
      return true if str_downcase[/(do.?n.?t)|(not?).?k?no/].present? # Don't know
      return true if str_downcase[/(do.?n.?t)|(not?).?remember/].present? # Don't remember
    end
    return true if str_downcase[/n\/a/].present?
    return true if str_downcase[/missing/].present? # Don't remember
    false
  end

  def self.normalized_and_corrected(str)
    str = unknown_and_absent_corrected(str).upcase
    return nil if str.blank? || %w[UNKNOWN MADE_WITHOUT_SERIAL].include?(str)
    normed = str.dup
    SUBSTITUTIONS.each do |key, value|
      normed.gsub!(/[#{key}]/, value)
      normed.gsub!(/[^\w]|_/, " ") # turn all non letter/numbers into spaces
    end
    normed.gsub(/^0+/, "").gsub(/\s+/, " ").strip # remove leading zeros and multiple spaces
  end

  # This is simple - but let's make sure it's consistent
  def self.no_space(serial = nil)
    return nil if serial.blank?
    serial&.gsub(/\s/, "")
  end

  def initialize(serial: nil, bike_id: nil)
    @serial = serial&.strip&.upcase
    @bike_id = bike_id
  end

  def normalized
    self.class.normalized_and_corrected(@serial)
  end

  def normalized_segments
    return [] if normalized.blank?
    (normalized.split(" ") + [SerialNormalizer.no_space(normalized)])
      .reject(&:empty?).uniq
  end

  def save_segments(bike_id)
    existing = NormalizedSerialSegment.where(bike_id: bike_id)
    existing.map(&:destroy) if existing.present?
    # NOTE: save segments if user_hidden, but not if otherwise not current
    return false if Bike.unscoped.where(example: false, likely_spam: false, deleted_at: nil)
      .where(id: bike_id).limit(1).none?
    normalized_segments.each do |seg|
      NormalizedSerialSegment.create(bike_id: bike_id, segment: seg)
    end
  end
end
