# Reverse-geocodes a coordinate into AddressRecord's assignable attributes, so a map
# pin prefills an address form from the provider the server itself geocodes with.
# Session-authenticated, so it stays out of the public /api namespace — and not named
# GeocodeController, which makes Rails include the GeocodeHelper service as a view helper
class ReverseGeocodeController < ApplicationController
  def index
    return render(json: {error: "Unauthorized"}, status: :unauthorized) if current_user.blank?

    coordinates = permitted_coordinates
    return render(json: {error: "Invalid coordinates"}, status: :bad_request) if coordinates.blank?

    render json: address_fields(GeocodeHelper.assignable_address_hash_for(**coordinates, new_attrs: true))
  end

  private

  # Rounded so a pin restored from the URL (which keeps 6 places) shares a Geocoder
  # cache key with the raw map centre it came from — 5 places is ~1m
  def permitted_coordinates
    latitude, longitude = %i[latitude longitude].map { Float(params[it], exception: false)&.round(5) }
    {latitude:, longitude:} if latitude&.between?(-90, 90) && longitude&.between?(-180, 180)
  end

  # Resolving the region here (rather than shipping the state code) mirrors
  # Geocodeable#assign_region_record: exactly one of the two region fields is set
  def address_fields(address)
    region_record_id = State.friendly_find(address[:region_string], country_id: address[:country_id])&.id

    address.slice(*Geocodeable::ADDRESS_ATTRS)
      .merge(region_record_id:, region_string: (address[:region_string] unless region_record_id))
  end
end
