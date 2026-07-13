# frozen_string_literal: true

module Registrations
  module New
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
