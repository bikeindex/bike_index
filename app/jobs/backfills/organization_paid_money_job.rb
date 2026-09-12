# frozen_string_literal: true

module Backfills
  # paid_money is calculated on save and nothing re-saves every organization, so the ones that
  # have paid read false until their next invoice or payment
  class OrganizationPaidMoneyJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      Invoice.active.in_batches(of: 500) do |invoices|
        organization_ids = invoices.select { |invoice| invoice.paid_money_in_full? }
          .map(&:organization_id)
        next if organization_ids.none?

        # update_all rather than update, to skip the associations job every organization would enqueue
        Organization.where(id: organization_ids).update_all(paid_money: true)
      end
    end
  end
end
