# frozen_string_literal: true

module SharedBlocks
  module Marketing
    module CallToActionBanner
      # The blue band that closes a page, with the action as its content. `dark` so a
      # secondary button reads on the blue
      class Component < ApplicationComponent
        def initialize(heading:, subheading: nil, illustration: true)
          @heading = heading
          @subheading = subheading
          @illustration = illustration
        end
      end
    end
  end
end
