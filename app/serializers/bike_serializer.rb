class BikeSerializer < ActiveModel::Serializer
  attributes :id, 
    :url,
    :api_url,
    :manufacturer_name,
    :manufacturer_id,
    :stolen,
    :name,
    :frame_manufacture_year,
    :frame_model,
    :seat_tube_length,
    :seat_tube_length_in_cm,
    :description,
    :rear_tire_narrow,
    :front_tire_narrow

  has_one :rear_wheel_size,
    :front_wheel_size,
    :primary_frame_color,
    :secondary_frame_color,
    :tertiary_frame_color,
    :handlebar_type,
    :frame_material,
    :front_gear_type,
    :rear_gear_type,
    :current_stolen_record

  has_many :components
  has_many :public_images
  

  def url
    bike_path(object)
  end

  def api_url
    api_v1_bike_path(object)
  end

end
