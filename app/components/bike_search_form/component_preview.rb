# frozen_string_literal: true

module BikeSearchForm
  class ComponentPreview < ApplicationComponentPreview
    def default
      @padded = true
      render(BikeSearchForm::Component.new())
    end

    private

    def default_options
      # {distance:, include_hidden_search_fields:, include_location_search:, include_organized_search_fields:, location:, query:, raw_serial:, search_address:, search_email:, search_model_audit_id:, search_path:, search_secondary:, search_stickers:, serial:, skip_serial_field:, stolenness:} }
      {}
    end
  end
end
