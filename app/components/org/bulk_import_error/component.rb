# frozen_string_literal: true

module Org::BulkImportError
  class Component < ApplicationComponent
    def initialize(bulk_import:, short_view: false)
      @bulk_import = bulk_import
      @short_view = short_view
    end

    def render?
      @bulk_import.import_errors?
    end

    private

    def other_errors
      @bulk_import.import_errors.except("file", "file_lines", "line", "ascend", "bikes")
    end
  end
end
