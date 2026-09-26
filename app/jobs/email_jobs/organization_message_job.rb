# frozen_string_literal: true

module EmailJobs
  class OrganizationMessageJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(organization_message_id)
      organization_message = OrganizationMessage.find(organization_message_id)
      notification = Notification.find_or_create_by(notifiable: organization_message, kind: "organization_message")

      Notifications::Deliver.track_email(notification) do
        OrganizedMailer.organization_message(organization_message).deliver_now
      end
    end
  end
end
