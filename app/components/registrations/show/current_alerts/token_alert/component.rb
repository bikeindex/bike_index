# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module TokenAlert
        # The page-body counterpart to TokenPrompt's dialog. The dialog opens on its own,
        # but closing it is the end of it — this renders the same prompt, whole, in the
        # alert spot, so nothing in it is lost with the dialog.
        class Component < ApplicationComponent
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

          # Picked the same way TokenPrompt picks, so the two can't disagree
          def prompt
            return @prompt if defined?(@prompt)

            @prompt = TokenPrompt::Component.prompt_for(bike: @bike, current_user: @current_user,
              current_alerts: @current_alerts, variant: :alert)
          end
        end
      end
    end
  end
end
