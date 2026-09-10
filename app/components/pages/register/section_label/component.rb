# frozen_string_literal: true

module Pages
  module Register
    module SectionLabel
      class Component < ApplicationComponent
        def initialize(text:, divider: false)
          @text = text
          @divider = divider
        end
      end
    end
  end
end
