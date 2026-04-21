# frozen_string_literal: true

module Org
  module BulkImportError
    class ComponentPreview < ApplicationComponentPreview
      def default
        render(Org::BulkImportError::Component.new(bulk_import:, short_display:))
      end
    end
  end
end
