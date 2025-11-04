# frozen_string_literal: true

module AddressDisplay
  class ComponentPreview < ApplicationComponentPreview
    # @group Address Variants

    def with_address_record
      render(AddressDisplay::Component.new(address_record:, visible_attribute:))
    end

    def with_address_hash
      render(AddressDisplay::Component.new(address_hash:, visible_attribute:))
    end

    # @param visible_attribute text "Visible attribute"
    def with_address_record_and_visible_attribute(visible_attribute: "city")
      render(AddressDisplay::Component.new(address_record:, visible_attribute:))
    end

    private

    def address_record
      AddressRecord.new(
        city: "Davis",
        region_record: State.friendly_find("CA"),
        country: Country.united_states,
        street: "One Shields Ave",
        street_2: "C/O BicyclingPlus",
        postal_code: "95616",
        latitude: 38.5449065,
        longitude: -121.7405167
      )
    end

    # Legacy address hash
    def address_hash
    end
  end
end
