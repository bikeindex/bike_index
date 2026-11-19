# frozen_string_literal: true

module Pages
  module Donate
    module OtherWays
      # The ways to give that don't go through the form, under each page's own heading
      class Component < ApplicationComponent
        private

        def ways = [translation(".daf"), translation(".stock"), translation(".match")]
      end
    end
  end
end
