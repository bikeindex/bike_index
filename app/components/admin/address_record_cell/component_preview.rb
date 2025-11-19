# frozen_string_literal: true

module Admin::AddressRecordCell
  class ComponentPreview < ApplicationComponentPreview
    # @group Address Variants

    def with_us_state
      address_record = AddressRecord.new(
        city: "Davis",
        region_record: State.friendly_find("CA"),
        country: Country.united_states
      )
      render(Admin::AddressRecordCell::Component.new(address_record:))
    end

    def with_non_us_country
      address_record = AddressRecord.new(
        city: "Toronto",
        region_string: "ON",
        country: Country.friendly_find("CA")
      )
      render(Admin::AddressRecordCell::Component.new(address_record:))
    end

    def with_city_only
      address_record = AddressRecord.new(city: "Portland")
      render(Admin::AddressRecordCell::Component.new(address_record:))
    end
  end
end
