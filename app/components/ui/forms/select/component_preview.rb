# frozen_string_literal: true

module UI
  module Forms
    module Select
      class ComponentPreview < ApplicationComponentPreview
        # @!group Examples
        def default
          {template: "ui/forms/select/component_preview/default"}
        end

        def with_blank
          {template: "ui/forms/select/component_preview/with_blank"}
        end

        def options_for_select
          {template: "ui/forms/select/component_preview/options_for_select"}
        end

        def options_from_collection_for_select
          {template: "ui/forms/select/component_preview/options_from_collection_for_select"}
        end
        # @!endgroup
      end
    end
  end
end
