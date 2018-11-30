class OrganizedMessageSerializer < ActiveModel::Serializer
  attributes :id, :kind, :created_at, :lat, :lng, :sender_id, :bike

  def created_at
    object.created_at.to_i
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
      id: bike_obj.id,
      title: bike_obj.title_string
    }
  end
end
