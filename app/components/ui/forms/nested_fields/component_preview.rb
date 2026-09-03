# frozen_string_literal: true

module UI
  module Forms
    module NestedFields
      class ComponentPreview < ApplicationComponentPreview
        # @!group Examples
        def default
          return missing_notice("organizations") if lookbook_organization.blank?

          {template: "ui/forms/nested_fields/component_preview/default",
           locals: {organization: lookbook_organization}}
        end
        # @!endgroup
      end
    end
  end
end
