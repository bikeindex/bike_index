# frozen_string_literal: true

module Backfills
  # Racing photo jobs (#4470) left some displays two attachments in a has_one_attached slot,
  # which any join to the attachments table returns twice. Keeps the newest of each
  class RecoveryDisplayDuplicatePhotosJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      record_ids = duplicate_attachments.distinct.pluck(:record_id)
      # A touch would re-run the display's photo processing callback
      ActiveRecord::Base.no_touching { duplicate_attachments.find_each(&:purge) }
      # Fragment caches key on updated_at, and may hold a purged photo's url
      RecoveryDisplay.unscoped.where(id: record_ids).update_all(updated_at: Time.current)
    end

    private

    def duplicate_attachments
      attachments = ActiveStorage::Attachment.where(record_type: "RecoveryDisplay")
      attachments.where.not(id: attachments.group(:record_id, :name).select("MAX(id)"))
    end
  end
end
