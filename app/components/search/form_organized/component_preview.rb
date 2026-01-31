# frozen_string_literal: true

module Search::FormOrganized
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Search::FormOrganized::Component.new(target_search_path:, target_frame:, interpreted_params:, skip_serial_field:, result_view:))
    end
  end
end
