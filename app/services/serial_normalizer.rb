class SerialNormalizerError < StandardError
end


class SerialNormalizer
  def initialize(creation_params = {})
    @bike_id = creation_params[:bike_id]
    @serial = creation_params[:serial]
    @serial = @serial.strip if @serial.present?
  end

  def normalized
    return "absent" if @serial.downcase == "absent"
    normalized = @serial.upcase
    key_hash = {
      'O'    => '0',
      '|IL'  => '1',
      'S'    => '5',
      'Z'    => '2',
      'B'    => '8',
    }
    key_hash.keys.each do |k|
      normalized.gsub!(/[#{k}]/, key_hash[k])
      normalized.gsub!(/[^\w]|[_]/, ' ') # turn all non letter/numbers into spaces
    end
    @serial = normalized.gsub(/^0+/,'').gsub(/\s+/,' ') # remove leading zeros and multiple spaces
  end

  def normalized_segments
    @serial = normalized 
    return nil if @serial == "absent"
    
    segments = @serial.split(' ')
    segments.reject! { |c| c.empty? }
    segments.uniq
  end

  def save_segments(bike_id)
    existing = NormalizedSerialSegment.where(bike_id: bike_id)
    existing.map(&:destroy) if existing.present?
    return false unless Bike.where(id: bike_id).present?
    
    segments = normalized_segments
    return false unless segments.present?
    segments.each do |seg|
      NormalizedSerialSegment.create(bike_id: bike_id, segment: seg)
    end
  end

end