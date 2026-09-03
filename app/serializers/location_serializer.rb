class LocationSerializer < ApplicationSerializer
  attributes :address, :name, :phone, :street, :city, :country, :state, :zipcode

  def address
    object.address_record&.formatted_address_string(render_country: true)
  end

  def street
    object.address_record&.street
  end

  def city
    object.address_record&.city
  end

  def country
    object.address_record&.country&.name
  end

  def state
    object.address_record&.region_record&.name
  end

  def zipcode
    object.address_record&.postal_code
  end
end
