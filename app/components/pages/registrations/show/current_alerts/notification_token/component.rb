# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module NotificationToken
          # The prompt reached from a parking or graduated notification email's link,
          # offering to mark the notification resolved (or confirming it already is)
          class Component < ApplicationComponent
            include PromptVariant

            MODAL_ID = "notification-token-modal"

            def initialize(bike:, token: nil, token_type: nil, matching_notification: nil, variant: :modal)
              @bike = bike
              @token = token
              @token_type = token_type
              @matching_notification = matching_notification
              @variant = variant
            end

            def render?
              @token.present? && @matching_notification.present?
            end

            private

            def graduated?
              @token_type == "graduated_notification"
            end

            def resolved?
              @matching_notification.resolved?
            end

            def resolved_text
              return translation(".you_have_already_marked_remaining", bike_type: @bike.type) if graduated?

              translation(".you_have_already_marked_resolved")
            end

            def resolve_button_text
              key = graduated? ? ".mark_graduated_resolved" : ".mark_parking_resolved"
              translation(key, bike_type: @bike.type)
            end

            def organization
              @matching_notification.organization
            end

            # The org's own copy for this notification kind
            def organization_snippet
              return @organization_snippet if defined?(@organization_snippet)

              @organization_snippet = organization&.mail_snippets&.enabled&.find_by(kind: @token_type)&.body
            end

            def organization_email
              organization&.auto_user&.email
            end
          end
        end
      end
    end
  end
end
