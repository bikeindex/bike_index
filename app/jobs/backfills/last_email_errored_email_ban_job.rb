# frozen_string_literal: true

module Backfills
  # EmailBan delivery_failure replaces user_emails.last_email_errored, which is being dropped -
  # create the bans track_email_delivery would have created for the errors already recorded
  class LastEmailErroredEmailBanJob < ApplicationJob
    include Sidekiq::IterableJob

    sidekiq_options queue: "low_priority", retry: false

    # batch_size has to be passed - the enumerator hands in_batches an explicit `of: nil` without it
    def build_enumerator(cursor:)
      active_record_relations_enumerator(user_emails, cursor:, batch_size: 1_000)
    end

    def each_iteration(batch)
      batch.each { EmailBan.create(reason: :delivery_failure, user: it.user, user_email: it) }
    end

    private

    def user_emails
      UserEmail.last_email_errored.includes(user: :user_emails)
    end
  end
end
