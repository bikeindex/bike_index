# frozen_string_literal: true

module UI
  module Forms
    module Files
      module Upload
        class ComponentPreview < ApplicationComponentPreview
          def default
            {template: "ui/forms/files/upload/component_preview/default"}
          end

          # The preview above the button stays empty and hidden unless the org has an avatar
          def with_existing_image
            {template: "ui/forms/files/upload/component_preview/with_existing_image",
             locals: {organization: lookbook_organization}}
          end
        end
      end
    end
  end
end
