# frozen_string_literal: true

module Pages
  module Donate
    module Hero
      # A donate page's eyebrow, h1 and lede, its content, in the column beside Pages::Donate::FormCard
      class Component < ApplicationComponent
        def initialize(eyebrow:, headline:)
          @eyebrow = eyebrow
          @headline = headline
        end
      end
    end
  end
end
