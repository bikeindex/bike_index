class StolenRecordV2Serializer < ApplicationSerializer
  # Legacy v2 API location format (ISO country suffix)
  def self.formatted_address_string_with_iso(stolen_record)
    return nil if stolen_record.blank?

    [stolen_record.formatted_address_string(render_country: false), stolen_record.country_iso]
      .reject(&:blank?).join(", ").presence
  end

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
    self.class.formatted_address_string_with_iso(object)
  end

  def latitude
    object.latitude_public
  end

  def longitude
    object.longitude_public
  end
end
