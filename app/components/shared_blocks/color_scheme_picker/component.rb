# frozen_string_literal: true

module SharedBlocks
  module ColorSchemePicker
    class Component < ApplicationComponent
      # url saves the pick to the account; without one it's only the cookie
      def initialize(color_scheme:, url: nil, compact: false)
        @color_scheme = color_scheme
        @url = url
        @compact = compact
      end

      private

      def options
        [["light", translation(".light"), "sun", "tw:text-yellow-500"],
          ["dark", translation(".dark"), "moon", "tw:text-indigo-400"],
          ["system", translation(".system"), "computer", "tw:text-gray-500"]]
      end
    end
  end
end
