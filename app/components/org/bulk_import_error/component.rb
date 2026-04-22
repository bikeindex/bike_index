# frozen_string_literal: true

module Org
  module BulkImportError
    class Component < ApplicationComponent
      def initialize(bulk_import:, short_display: false, in_admin: false)
        @bulk_import = bulk_import
        @short_display = short_display
        @in_admin = in_admin
      end

      def render?
        @bulk_import.import_errors?
      end

      private

      def short_text
        errors = []
        errors << short_file_text if @bulk_import.file_errors.present?
        errors << translation(".unknown_ascend_name") if @bulk_import.ascend_errors.present?
        errors << short_line_text if @bulk_import.line_errors.present?
        errors.join(", ")
      end

      def short_file_text
        file_errors = @bulk_import.file_errors
        return file_errors.first if file_errors.length == 1 && file_errors.first.match?(/Invalid file extension/i)
        translation(".file")
      end

      def short_line_text
        count = @bulk_import.line_errors.length
        helpers.pluralize(helpers.number_with_delimiter(count), translation(".line_error"))
      end

      def other_errors
        @bulk_import.import_errors.except("file", "file_lines", "line", "ascend", "bikes")
      end
    end
  end
end
