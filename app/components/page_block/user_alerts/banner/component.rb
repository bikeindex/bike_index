# frozen_string_literal: true

module PageBlock
  module UserAlerts
    module Banner
      # The chrome the alerts that don't interrupt share: a notice below the navbar
      class Component < ApplicationComponent
        def initialize(header: nil)
          @header = header
        end
      end
    end
  end
end
