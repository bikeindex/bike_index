class BikeV2ShowSerializer < BikeV2Serializer
  self.root = 'bike'
  attributes :registration_created_at,
    :registration_updated_at,
    :url,
    :api_url,
    :manufacturer_id,
    :paint_description,
    :name,
    :frame_size,
    :description,
    :rear_tire_narrow,
    :front_tire_narrow,
    :type_of_cycle,
    :images

  has_one :rear_wheel_size,
    :front_wheel_size,
    :handlebar_type,
    :frame_material,
    :front_gear_type,
    :rear_gear_type,
    :stolen_record

  has_many :components

  def images
    object.public_images
  end
  
  def type_of_cycle
    object.cycle_type.name
  end  
  
  def url
    "#{ENV['BASE_URL']}/bikes/#{object.id}"
  end

  def api_url
    "#{ENV['BASE_URL']}/api/v1/bikes/#{object.id}"
  end
  
  def registration_created_at
    object.created_at.to_i
  end
  
  def registration_updated_at
    object.updated_at.to_i
  end

  def stolen_record
    object.current_stolen_record if object.current_stolen_record.present?
  end

  def photo
    if object.public_images.present?
      object.public_images.first.image_url(:large)
    elsif object.stock_photo_url.present?
      object.stock_photo_url
    else
      nil
    end    
  end

end
