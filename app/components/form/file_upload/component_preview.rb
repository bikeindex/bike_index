# frozen_string_literal: true

module Form
  module FileUpload
    class ComponentPreview < ApplicationComponentPreview
      def default
        {template: "form/file_upload/component_preview/default"}
      end
    end
  end
end
