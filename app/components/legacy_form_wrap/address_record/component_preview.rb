# frozen_string_literal: true

module LegacyFormWrap::AddressRecord
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(LegacyFormWrap::AddressRecord::Component.new(form_object:, address_record:, street_placeholder:, street_required_text:))
    end
  end
end
