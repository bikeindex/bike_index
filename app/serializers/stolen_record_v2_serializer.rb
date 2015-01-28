class StolenRecordV2Serializer < ActiveModel::Serializer
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
    :id,

  def date_stolen
    object.date_stolen.to_i
  end

  def created_at
    object.created_at.to_i
  end

  def location
    a = [object.city]
    a << object.state.abbreviation if object.state.present?
    a << object.zipcode if object.zipcode.present?
    a << object.country.iso if object.country.present? && object.country.iso != 'US'
    a.compact.join(', ')
  end
end
