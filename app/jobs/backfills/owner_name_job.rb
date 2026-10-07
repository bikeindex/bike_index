# frozen_string_literal: true

module Backfills
  # SSO and emailed-link accounts started without a name, so registering their own bike left the
  # ownership's owner_name blank. Resaving the bike copies a name the account has since gained
  class OwnerNameJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      Ownership.current.claimed.where(owner_name: [nil, ""])
        .joins(:user).where.not(users: {name: [nil, ""]})
        .pluck(:bike_id)
        .each { CallbackJobs::AfterBikeSaveJob.perform_async(it, true, true) }
    end
  end
end
