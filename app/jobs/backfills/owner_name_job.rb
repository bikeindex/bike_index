# frozen_string_literal: true

module Backfills
  # Claiming overwrote owner_name with the account's name even when the account had none,
  # wiping the name typed at registration. Saving restores it from registration_info
  class OwnerNameJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      Ownership.current.claimed.where(owner_name: [nil, ""])
        .where("registration_info ->> 'user_name' <> ''").find_each(&:save)
    end
  end
end
