# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        # A prompt renders as both at once, so what differs between them is asked here
        module PromptVariant
          private

          def alert? = @variant == :alert

          # The alert's form needs its own field ids — no second #token in the document
          def form_namespace = alert? ? "alert" : nil
        end
      end
    end
  end
end
