# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module TokenPrompt
        # Picks the one prompt a request's tokens have earned. Rendered outside the
        # page's fragment cache — these are per-request, and a recovery token is spent
        # as it's read, so a cached copy could never be served again anyway.
        class Component < ApplicationComponent
          # Like the legacy overlays, only one opens — they're modals, and stacked
          # dialogs would bury each other. Recovery beats a notification (the legacy
          # partial let it override), and claiming is the fallback. Legacy rendered the
          # claim pitch inline so it could coexist; here a second token suppresses it.
          #
          # TokenAlert picks the same way, from the same arguments, so the alert in the
          # page body and the dialog it opens can't disagree about which prompt won.
          def self.prompt_for(bike:, current_user: nil, current_alerts: nil, variant: :modal)
            return if current_alerts.blank?

            [RecoveryPrompt::Component.new(bike:, variant:, stolen_record: current_alerts.recovered_stolen_record),
              NotificationToken::Component.new(bike:, variant:, token: current_alerts.token,
                token_type: current_alerts.token_type, matching_notification: current_alerts.matching_notification),
              ClaimInvitation::Component.new(bike:, current_user:, variant:,
                claim_message: current_alerts.claim_message)].find(&:render?)
          end

          def initialize(bike:, current_user: nil, current_alerts: nil)
            @bike = bike
            @current_user = current_user
            @current_alerts = current_alerts
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

            @prompt = self.class.prompt_for(bike: @bike, current_user: @current_user, current_alerts: @current_alerts)
          end
        end
      end
    end
  end
end
