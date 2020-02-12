class ParkingNotificationSerializer < ActiveModel::Serializer
  attributes :id,
             :kind,
             :kind_humanized,
             :created_at,
             :lat,
             :lng,
             :user_id,
             :user_display_name,
             :bike,
             :repeat_number,
             :impound_record_id,
             :impound_record_at

  def created_at
    object.created_at.to_i
  end

  def user_id
    object.user_id
  end

  def user_display_name
    object.user&.display_name
  end

  def lat
    object.latitude
  end

  def lng
    object.longitude
  end

  def impound_record_at
    object.impound_record&.created_at&.to_i
  end

  def bike
    bike_obj = object.bike
    {
      id: bike_obj&.id,
      title: bike_obj&.title_string,
    }
  end
end
