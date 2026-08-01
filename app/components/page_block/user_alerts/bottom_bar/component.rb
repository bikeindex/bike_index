# frozen_string_literal: true

module PageBlock
  module UserAlerts
    module BottomBar
      # The chrome the alerts that don't interrupt share: a bar pinned across the bottom
      # of the page, carrying a single link
      class Component < ApplicationComponent
        def initialize(href:, text:, data: {})
          @href = href
          @text = text
          @data = data
        end
      end
    end
  end
end
