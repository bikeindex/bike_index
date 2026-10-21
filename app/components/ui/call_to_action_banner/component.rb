# frozen_string_literal: true

module UI
  module CallToActionBanner
    # The blue band that closes a page, with the action as its content
    class Component < ApplicationComponent
      def initialize(heading:, subheading: nil, illustration: true, wide: false)
        @heading = heading
        @subheading = subheading
        @illustration = illustration
        @wide = wide
      end
    end
  end
end
