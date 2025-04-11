# frozen_string_literal: true

module LegacyFormWrap::AddressRecord
  class Component < ApplicationComponent
    def initialize(form_object:, address_record:, street_placeholder:, street_required_text:)
      @form_object = form_object
    @address_record = address_record
    @street_placeholder = street_placeholder
    @street_required_text = street_required_text
    end
  end
end
