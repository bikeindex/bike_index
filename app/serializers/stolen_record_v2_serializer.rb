class StolenRecordV2Serializer < ApplicationSerializer
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

  def date_stolen
    object.date_stolen.to_i
  end

  def created_at
    object.created_at.to_i
  end

  def location
    object.address
  end

  def latitude
    object.latitude_public
  end

  def longitude
    object.longitude_public
  end
end
