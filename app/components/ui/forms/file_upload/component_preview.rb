# frozen_string_literal: true

module UI
  module Forms
    module FileUpload
      class ComponentPreview < ApplicationComponentPreview
        def default
          {template: "ui/forms/file_upload/component_preview/default"}
        end
      end
    end
  end
end
