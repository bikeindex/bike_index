class BikeSerializer < ActiveModel::Serializer
  attributes :id, 
    :url,
    :api_url,
    :manufacturer_name,
    :manufacturer_id,
    :frame_colors,
    :paint_description,
    :stolen,
    :name,
    :frame_manufacture_year,
    :frame_model,
    :description,
    :rear_tire_narrow,
    :front_tire_narrow,
    :registration_created_at,
    :registration_updated_at

  has_one :rear_wheel_size,
    :front_wheel_size,
    :handlebar_type,
    :frame_material,
    :front_gear_type,
    :rear_gear_type,
    :current_stolen_record

  has_many :components
  has_many :public_images
  
  def url
    bike_url(object)
  end

  def api_url
    api_v1_bike_url(object)
  end
  
  def registration_created_at
    object.created_at
  end
  
  def registration_updated_at
    object.updated_at
  end

end
