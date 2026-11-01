# frozen_string_literal: true

module Backfills
  # Before #4579, no_duplicate defaulted to false
  class BulkImportAllowDuplicateJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      BulkImport.where("data IS NULL OR NOT data ? 'allow_duplicate'").find_each do |bulk_import|
        no_duplicate = Binxtils::InputNormalizer.boolean(bulk_import.data&.dig("no_duplicate"))
        bulk_import.update_column(:data, (bulk_import.data || {}).except("no_duplicate").merge("allow_duplicate" => !no_duplicate))
      end
    end
  end
end
