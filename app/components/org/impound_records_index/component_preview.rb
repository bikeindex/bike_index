# frozen_string_literal: true

module Org::ImpoundRecordsIndex
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Org::ImpoundRecordsIndex::Component.new(per_page:, interpreted_params:, pagy:, impound_records:))
    end
  end
end
