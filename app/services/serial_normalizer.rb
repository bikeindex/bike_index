class SerialNormalizerError < StandardError
end


class SerialNormalizer
  def initialize(creation_params = nil)
    @bike_id = creation_params[:bike_id]
    @serial = creation_params[:serial]
    @bike = find_bike
  end

  def find_bike
    return nil unless @bike_id.present?
    begin
    return Bike.find(@bike_id)
    rescue
      raise SerialNormalizerError, "Oh no! We couldn't find that bike"
    end
  end

  def normalized
    i = @serial.upcase
    i = i.gsub(/[O]/,'0').gsub(/[IL]/,'1')
    i = i.gsub(/[S]/,'5').gsub(/[S]/,'5').gsub(/[Z]/,'2').gsub(/[B]/,'8')
    return i
  end

  def set_normalized
    @serial = @bike.serial_number
    @bike.serial_normalized = normalized
    @bike.save
  end

end