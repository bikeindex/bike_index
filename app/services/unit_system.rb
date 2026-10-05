# frozen_string_literal: true

module UnitSystem
  extend Functionable

  KILOMETERS_PER_MILE = 1.609344
  DISTANCE_UNITS = %w[km mi].freeze

  # A user's own setting, then their address, then wherever the request came from
  def metric?(user: nil, country_id: nil)
    return user.preferred_unit_system_metric? if user&.preferred_unit_system.present?

    country_id = user&.address_record&.country_id || country_id
    country_id.blank? || country_id != Country.united_states_id
  end

  def distance_unit(metric)
    metric ? "km" : "mi"
  end

  # The API's distances have always been miles
  def permitted_distance_unit(unit)
    DISTANCE_UNITS.include?(unit) ? unit : "mi"
  end

  def miles_to_kilometers(miles)
    miles.to_f * KILOMETERS_PER_MILE
  end

  def kilometers_to_miles(kilometers)
    kilometers.to_f / KILOMETERS_PER_MILE
  end

  def to_miles(distance, unit)
    (unit == "km") ? kilometers_to_miles(distance) : distance
  end

  def from_miles(miles, unit)
    (unit == "km") ? miles_to_kilometers(miles) : miles
  end
end
