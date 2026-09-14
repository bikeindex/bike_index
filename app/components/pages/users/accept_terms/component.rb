# frozen_string_literal: true

module Pages
  module Users
    module AcceptTerms
      # A terms page: the document, and an agree-and-submit bar sticky through its many
      # screens. The checkbox is required client side because the flash for an unchecked
      # submit is a toast at the bottom, over that bar.
      class Component < ApplicationComponent
        def initialize(user:, attribute:, label:, submit_text:)
          @user = user
          @attribute = attribute
          @label = label
          @submit_text = submit_text
        end
      end
    end
  end
end
