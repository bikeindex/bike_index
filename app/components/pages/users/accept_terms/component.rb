# frozen_string_literal: true

module Pages
  module Users
    module AcceptTerms
      # The agree-and-submit bar on the two terms pages, sticky so it stays reachable
      # through a document that runs many screens long. The checkbox is required here
      # rather than only server side - the flash for an unchecked submit renders as a
      # toast over this bar, which is the control it is telling the reader to use.
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
