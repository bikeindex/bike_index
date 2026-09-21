# frozen_string_literal: true

module Pages
  module Org
    module BulkImportError
      # Built from unsaved BulkImports, so the scenarios cover error shapes the database
      # may hold no example of — and a preview never renders a real organization's import
      class ComponentPreview < ApplicationComponentPreview
        LINE_ERRORS = {
          "line" => [[4, "Serial can't be blank"],
            [17, "Manufacturer can't be blank", "Color can't be blank"],
            "Row 23 was skipped"]
        }.freeze

        FILE_ERRORS = {
          "file" => ["Invalid file extension: .pages", "Missing required header: serial"],
          "file_lines" => [nil, 1]
        }.freeze

        # An error the importer stored under a key the component doesn't case out
        OTHER_ERRORS = LINE_ERRORS.merge("bulk_import_worker" => "Timed out after 300s").freeze

        # @display legacy_stylesheet true
        def default
          render(Pages::Org::BulkImportError::Component.new(bulk_import: bulk_import(LINE_ERRORS)))
        end

        # One line of it, as the organization's imports table shows in a row
        # @display legacy_stylesheet true
        def short_display
          render(Pages::Org::BulkImportError::Component.new(
            bulk_import: bulk_import(LINE_ERRORS), short_display: true
          ))
        end

        # A file the importer couldn't read, with the line each error stopped on
        # @display legacy_stylesheet true
        def file_errors
          render(Pages::Org::BulkImportError::Component.new(bulk_import: bulk_import(FILE_ERRORS)))
        end

        # @display legacy_stylesheet true
        def unrecognized_errors
          render(Pages::Org::BulkImportError::Component.new(bulk_import: bulk_import(OTHER_ERRORS)))
        end

        private

        def bulk_import(import_errors)
          ::BulkImport.new(import_errors:)
        end
      end
    end
  end
end
