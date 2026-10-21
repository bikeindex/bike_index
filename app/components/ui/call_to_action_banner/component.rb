# frozen_string_literal: true

module UI
  module CallToActionBanner
    # The blue band that closes a page, with the action as its content. It cancels the
    # footer's top margin, so it has to be the last thing on the page
    class Component < ApplicationComponent
      def initialize(heading:, subheading: nil, illustration: true, max_width: "tw:max-w-6xl")
        @heading = heading
        @subheading = subheading
        @illustration = illustration
        @max_width = max_width
      end
    end
  end
end
