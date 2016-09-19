class SerialNormalizerError < StandardError
end

class SerialNormalizer
  def initialize(creation_params = {})
    @serial = creation_params[:serial] && creation_params[:serial].strip.upcase
    @bike_id = creation_params[:bike_id]
  end

  def normalized
    return 'absent' if @serial == 'ABSENT'
    normed = @serial.upcase
    serial_substitutions.each do |key, value|
      normed.gsub!(/[#{key}]/, value)
      normed.gsub!(/[^\w]|[_]/, ' ') # turn all non letter/numbers into spaces
    end
    normed.gsub(/^0+/, '').gsub(/\s+/, ' ').strip # remove leading zeros and multiple spaces
  end

  def normalized_segments
    return [] if @serial == 'absent'
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

  def to_h
    {
      normalized: normalized,
      normalized_segments: normalized_segments
    }
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
