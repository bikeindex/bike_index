# frozen_string_literal: true

module SearchRadiusMetricable
  extend ActiveSupport::Concern

  included do
    before_validation :set_search_radius
  end

  def bounding_box
    Geocoder::Calculations.bounding_box(search_coordinates, search_radius_miles)
  end

  def search_radius_metric_units?
    @search_radius_metric_units ||=
      self.class == Organization ? metric_units? : organization&.metric_units?
  end

  def search_radius_kilometers
    (search_radius_miles.to_f * "1.609344".to_f).to_i
  end

  def search_radius_kilometers=(val)
    if val.present?
      self.search_radius_miles = val.to_f / "1.609344".to_f
    end
  end

  def search_radius_display
    if search_radius_metric_units?
      "#{search_radius_kilometers} km"
    else
      "#{search_radius_miles.to_i} miles"
    end
  end

  def set_search_radius
    if search_radius_miles.blank? || search_radius_miles < 1
      self.search_radius_miles = organization&.search_radius_miles || 50
      # switch km default to 100
      self.search_radius_kilometers = 100 if search_radius_metric_units? && search_radius_miles == 50
    end
  end
end
