class StolenRecordSerializer < ActiveModel::Serializer
  attributes :date_stolen,
    :location,
    :latitude,
    :longitude,
    :theft_description,
    :locking_description,
    :lock_defeat_description,
    :police_report_number,
    :police_report_department

  def location
    a = [object.city]
    a << object.state.abbreviation if object.state.present?
    a << object.zipcode if object.zipcode.present?
    a << object.country.iso if object.country.present? && object.country.iso != 'US'
    a.compact.join(', ')
  end
end
