class OrganizedMessageIndexSerializer < ActiveModel::Serializer

  attributes :id, :kind, :created_at, :lat, :lng

  def created_at
    object.created_at.to_i
  end

  def lat
    object.latitude
  end

  def lng
    object.longitude
  end
end
