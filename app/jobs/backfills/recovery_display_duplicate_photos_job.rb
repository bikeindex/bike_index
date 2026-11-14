# frozen_string_literal: true

module Backfills
  # Racing photo jobs left some displays two attachments in a has_one_attached slot; keeps the newest
  class RecoveryDisplayDuplicatePhotosJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      attachments = ActiveStorage::Attachment.where(record_type: "RecoveryDisplay")
      duplicates = attachments.where.not(id: attachments.group(:record_id, :name).select("MAX(id)")).to_a
      # A touch would re-run the display's photo processing callback
      ActiveRecord::Base.no_touching { duplicates.each(&:purge) }
      # Busts fragment caches holding a purged photo's url
      RecoveryDisplay.unscoped.where(id: duplicates.map(&:record_id)).update_all(updated_at: Time.current)
    end
  end
end
