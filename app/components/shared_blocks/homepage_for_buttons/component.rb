# frozen_string_literal: true

module SharedBlocks
  module HomepageForButtons
    class Component < ApplicationComponent
      def initialize(skip_theft: false)
        @skip_theft = skip_theft
      end
    end
  end
end
