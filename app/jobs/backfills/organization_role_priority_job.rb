# frozen_string_literal: true

module Backfills
  # The priority column arrived defaulted to 0, so every role of a user's ties with the rest and
  # OrganizationRole.ordered_for falls back to id. Number them by when they were created, which
  # is the order they were already listed in.
  class OrganizationRolePriorityJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      User.joins(:organization_roles).distinct.find_each(batch_size: 500) do |user|
        renumber(user)
      end
    end

    private

    # update_all rather than update, to skip the processing worker every role would enqueue
    def renumber(user)
      OrganizationRole.where(user_id: user.id).order(:created_at, :id)
        .each_with_index do |organization_role, index|
        next if organization_role.priority == index

        OrganizationRole.where(id: organization_role.id).update_all(priority: index)
      end
    end
  end
end
