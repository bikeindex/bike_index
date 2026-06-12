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
    a << object.region if object.region.present?
    a << object.postal_code if object.postal_code.present?
    a << object.country.iso if object.country.present? && object.country.iso != "US"
    a.compact.join(", ")
  end
end
