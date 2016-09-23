class SerialNormalizer
  def initialize(serial: nil, bike_id: nil)
    @serial = serial && serial.strip.upcase
    @bike_id = bike_id
  end

  def normalized
    return 'absent' if @serial.blank? || @serial == 'ABSENT'
    normed = @serial.dup
    serial_substitutions.each do |key, value|
      normed.gsub!(/[#{key}]/, value)
      normed.gsub!(/[^\w]|[_]/, ' ') # turn all non letter/numbers into spaces
    end
    normed.gsub(/^0+/, '').gsub(/\s+/, ' ').strip # remove leading zeros and multiple spaces
  end

  def normalized_segments
    return [] if normalized == 'absent'
    normalized.split(' ').reject(&:empty?).uniq
  end

  def save_segments(bike_id)
    existing = NormalizedSerialSegment.where(bike_id: bike_id)
    existing.map(&:destroy) if existing.present?
    return false unless Bike.where(id: bike_id).present?
    normalized_segments.each do |seg|
      NormalizedSerialSegment.create(bike_id: bike_id, segment: seg)
    end
  end

  private

  def serial_substitutions
    {
      '|IL' => '1',
      'O' => '0',
      'S' => '5',
      'Z' => '2',
      'B' => '8'
    }
  end
end
