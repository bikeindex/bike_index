# frozen_string_literal: true

module Org::BulkImportError
  class ComponentPreview < ApplicationComponentPreview
    def default
      render(Org::BulkImportError::Component.new(bulk_import:, short_view:))
    end
  end
end
