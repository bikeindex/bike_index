class LocationSerializer < ActiveModel::Serializer
  attributes :address, :name, :phone, :street, :city, :country, :state, :zipcode

  def country
    object.country&.name
  end

  def state
    object.state&.name
  end
end
