class BikeSerializer < ActiveModel::Serializer
  attributes :id,
    :serial,
    :registration_created_at,
    :registration_updated_at,
    :url,
    :api_url,
    :manufacturer_name,
    :manufacturer_id,
    :frame_colors,
    :paint_description,
    :stolen,
    :name,
    :year,
    :frame_model,
    :description,
    :rear_tire_narrow,
    :front_tire_narrow,
    :photo,
    :thumb,
    :title

  has_one :rear_wheel_size,
    :front_wheel_size,
    :handlebar_type,
    :frame_material,
    :front_gear_type,
    :rear_gear_type,
    :stolen_record
    
  
  def url
    bike_url(object)
  end

  def api_url
    api_v1_bike_url(object)
  end

  def title
    object.title_string + "(#{object.frame_colors.to_sentence.downcase})"
  end
  
  def registration_created_at
    object.created_at
  end
  
  def registration_updated_at
    object.updated_at
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

  def thumb
    if object.public_images.present?
      object.public_images.first.image_url(:small)
    elsif object.stock_photo_url.present?
      small = object.stock_photo_url.split('/')
      ext = "/small_" + small.pop
      small.join('/') + ext
    else
      nil
    end    
  end

end
