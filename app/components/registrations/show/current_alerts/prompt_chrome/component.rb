# frozen_string_literal: true

module Registrations
  module Show
    module CurrentAlerts
      module PromptChrome
        # What a token prompt is wrapped in. The dialog opens itself and is gone once
        # closed, so the same prompt renders again as an alert in the page body —
        # everything the dialog holds, minus the chrome that took it away.
        class Component < ApplicationComponent
          def initialize(variant:, id:, title: nil)
            @variant = variant
            @id = id
            @title = title
          end

          private

          def alert? = @variant == :alert
        end
      end
    end
  end
end
