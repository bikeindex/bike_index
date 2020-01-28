class AbandonedRecordSerializer < ActiveModel::Serializer
  attributes :id, :created_at, :lat, :lng, :user_id, :bike

  def created_at
    object.created_at.to_i
  end

  def user_id
    object.user_id
  end

  def lat
    object.latitude
  end

  def lng
    object.longitude
  end

  def bike
    bike_obj = object.bike
    {
      id: bike_obj&.id,
      title: bike_obj&.title_string,
    }
  end
end
