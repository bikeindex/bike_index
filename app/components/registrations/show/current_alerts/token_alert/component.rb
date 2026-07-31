# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module TokenAlert
        # The page-body counterpart to TokenPrompt's modal. The modal opens on its own,
        # but closing it is the end of it — this leaves a way back to it in the alert
        # spot, next to the alerts about the registration's current state.
        class Component < ApplicationComponent
          def initialize(bike:, current_user: nil, current_alerts: nil)
            @bike = bike
            @current_user = current_user
            @current_alerts = current_alerts
          end

          def render?
            prompt.present?
          end

          private

          def prompt
            return @prompt if defined?(@prompt)

            @prompt = TokenPrompt::Component.prompt_for(bike: @bike, current_user: @current_user,
              current_alerts: @current_alerts)
          end

          # The dialog is TokenPrompt's, rendered outside this page's fragment cache —
          # ui--modal opens it from any [data-open-modal] in the document
          def modal_id = prompt.class::MODAL_ID
        end
      end
    end
  end
end
