# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module TokenPrompt
          # Picks the one prompt a request's tokens have earned, and renders it as the
          # dialog or as the alert in the page body
          class Component < ApplicationComponent
            # Only one, like the legacy overlays — stacked dialogs would bury each other.
            # Recovery beats a notification, and claiming is the fallback
            def self.prompt_for(bike:, current_user: nil, current_alerts: {}, variant: :modal)
              return if current_alerts.blank?

              [RecoveryPrompt::Component.new(bike:, variant:, stolen_record: current_alerts[:recovered_stolen_record]),
                NotificationToken::Component.new(bike:, variant:, token: current_alerts[:token],
                  token_type: current_alerts[:token_type],
                  matching_notification: current_alerts[:matching_notification]),
                ClaimInvitation::Component.new(bike:, current_user:, variant:,
                  claim_message: current_alerts[:claim_message])].find(&:render?)
            end

            def initialize(bike:, current_user: nil, current_alerts: {}, variant: :modal)
              @bike = bike
              @current_user = current_user
              @current_alerts = current_alerts
              @variant = variant
            end

            def render?
              prompt.present?
            end

            def call
              render(prompt)
            end

            private

            def prompt
              return @prompt if defined?(@prompt)

              @prompt = self.class.prompt_for(bike: @bike, current_user: @current_user,
                current_alerts: @current_alerts, variant: @variant)
            end
          end
        end
      end
    end
  end
end
