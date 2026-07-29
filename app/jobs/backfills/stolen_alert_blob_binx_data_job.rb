# frozen_string_literal: true

module Backfills
  # Stamp the alert images minted before Images::StolenProcessor set binx_data, so
  # CleanUnattachedBlobsJob's filename fallback can go.
  class StolenAlertBlobBinxDataJob < ApplicationJob
    include Sidekiq::IterableJob

    sidekiq_options queue: "low_priority", retry: false

    # StolenProcessor names them "stolen-<stolen_record_id>-<template>.jpeg" - anything else
    # matching the ILIKE is a file a user named, and stamping it would exempt it from the reaper
    FILENAME_MATCHER = /\Astolen-(\d+)-/

    def build_enumerator(cursor:)
      active_record_records_enumerator(blobs, cursor:)
    end

    # Stamped rows drop out of the relation, but the cursor moves forward by id, so a resumed
    # run doesn't skip anything
    def each_iteration(blob)
      stolen_record_id = blob.filename.to_s[FILENAME_MATCHER, 1]
      return if stolen_record_id.blank?

      blob.update_columns(binx_data: {"stolen_record_id" => stolen_record_id.to_i})
    end

    private

    def blobs
      ActiveStorage::Blob.where(binx_data: nil).where("filename ILIKE ?", "stolen-%")
    end
  end
end
