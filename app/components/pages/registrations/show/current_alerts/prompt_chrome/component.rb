# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module CurrentAlerts
        module PromptChrome
          # What a token prompt is wrapped in — the dialog that opens itself, and the alert
          # holding the same thing once it's dismissed
          class Component < ApplicationComponent
            include PromptVariant

            def initialize(variant:, id:, title: nil)
              @variant = variant
              @id = id
              @title = title
            end
          end
        end
      end
    end
  end
end
