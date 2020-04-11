# frozen_string_literal: true

# Decorates a Geocoder:Result object to consistify its interface
# with that of `Geocodeable` ActiveRecord objects.
# see: app/models/concerns/geocodeable.rb
class RequestGeolocationInfo < SimpleDelegator
  attr_accessor :address
  private_class_method :new

  def self.decorate(object)
    new(object) if object.respond_to?(:postal_code)
  end

  def country
    @country ||= Country.fuzzy_find(country_code)
  end

  def zipcode
    postal_code
  end

  def bike_location_info?
    Geocodeable.bike_location_info?(self)
  end
end
