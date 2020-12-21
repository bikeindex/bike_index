class StolenRecordSerializer < ApplicationSerializer
  attributes :date_stolen,
    :location,
    :latitude,
    :longitude,
    :theft_description,
    :locking_description,
    :lock_defeat_description,
    :police_report_number,
    :police_report_department,
    :created_at,
    :create_open311,
    :id

  def latitude
    object.latitude_public
  end

  def longitude
    object.longitude_public
  end

  def location
    a = [object.city]
    a << object.state.abbreviation if object.state.present?
    a << object.zipcode if object.zipcode.present?
    a << object.country.iso if object.country.present? && object.country.iso != "US"
    a.compact.join(", ")
  end
end
