# frozen_string_literal: true

module SearchRadiusMetricable
  extend ActiveSupport::Concern

  DEFAULT_RADIUS_MILES = 50

  class_methods do
    def miles_to_kilometers(num)
      (num.to_f * "1.609344".to_f)
    end

    def kilometers_to_miles(num)
      num.to_f / "1.609344".to_f
    end
  end

  included do
    before_validation :set_search_radius
  end

  def bounding_box
    GeocodeHelper.bounding_box(search_coordinates, search_radius_miles)
  end

  def search_radius_metric_units?
    @search_radius_metric_units ||= metric_units? # assign because through multiple tables
  end

  def default_search_radius_miles
    search_rad = organization&.search_radius_miles if self.class != Organization
    search_rad || DEFAULT_RADIUS_MILES
  end

  def search_radius_kilometers
    self.class.miles_to_kilometers(search_radius_miles).to_i
  end

  def search_radius_kilometers=(val)
    self.search_radius_miles = self.class.kilometers_to_miles(val) if val.present?
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
      self.search_radius_miles = default_search_radius_miles
      # switch km default to 100
      self.search_radius_kilometers = 100 if search_radius_metric_units? && search_radius_miles == default_search_radius_miles
    end
  end
end
