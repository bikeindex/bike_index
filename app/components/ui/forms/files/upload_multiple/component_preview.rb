# frozen_string_literal: true

module UI
  module Forms
    module Files
      module UploadMultiple
        class ComponentPreview < ApplicationComponentPreview
          # Nothing answers the url here, so a pick shows the failed state rather than
          # storing anything - admin/news/edit is where the whole cycle runs
          def default
            {template: "ui/forms/files/upload_multiple/component_preview/default"}
          end
        end
      end
    end
  end
end
