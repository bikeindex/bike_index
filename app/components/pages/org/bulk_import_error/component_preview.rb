# frozen_string_literal: true

module Pages
  module Org
    module BulkImportError
      class ComponentPreview < ApplicationComponentPreview
        def default
          render(Pages::Org::BulkImportError::Component.new(bulk_import:, short_display:))
        end
      end
    end
  end
end
