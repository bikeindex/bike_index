# frozen_string_literal: true

require "image_processing/vips"

class Images::ProcessRecoveryDisplayPhotoJob < ApplicationJob
  DIMENSIONS = [800, 800].freeze

  sidekiq_options retry: false

  # TODO: After Backfills::RecoveryDisplayMigrateImageJob is finished, remove recovery_display keyword arg
  def perform(recovery_display_id, remote_photo_url = nil, force_regenerate = false, recovery_display: nil)
    recovery_display ||= RecoveryDisplay.find_by_id(recovery_display_id)
    return unless recovery_display.present?

    recovery_display.skip_callback_job = true

    # Prevent touching the recovery_display, which kicks off a job
    ActiveRecord::Base.no_touching do
      # If remote_photo_url is provided, download and attach it
      if attach_remote_photo_url?(recovery_display:, remote_photo_url:, force_regenerate:)
        downloaded_image = Down.download(remote_photo_url)
        recovery_display.photo.attach(io: downloaded_image, filename: "recovery-#{recovery_display_id}")
      end

      # Process the photo to create photo_processed
      process_photo(recovery_display, force_regenerate:)
    end
  end

  private

  def attach_remote_photo_url?(recovery_display:, remote_photo_url:, force_regenerate:)
    return false if remote_photo_url.blank?

    force_regenerate || !recovery_display.photo.attached?
  end

  def process_photo(recovery_display, force_regenerate: false)
    return unless recovery_display.photo.attached?
    return if recovery_display.photo_processed.attached? && !force_regenerate

    processed_blob = ActiveStorage::Blob.create_and_upload!(
      io: generate_square_image(recovery_display.photo),
      filename: "square_recovery-#{recovery_display.id}.jpeg"
    )
    processed_blob.analyze

    recovery_display.photo_processed.attach(processed_blob)
    recovery_display
  end

  def generate_square_image(photo)
    photo.blob.open do |file|
      ImageProcessing::Vips.source(file)
        .resize_to_fill(*DIMENSIONS)
        .convert("jpeg")
        .call
    end
  end
end
