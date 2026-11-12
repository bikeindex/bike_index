# frozen_string_literal: true

module Pages
  module Donate
    module TenPercent
      # A prompt for someone whose bike was recovered: type its value and donate--ten-percent fills 10% of it
      # into the one-time form's other amount. Its input is named nothing, so the form submits only that amount.
      # open: expanded on load; the donate--page:open-ten-percent event expands it later
      class Component < ApplicationComponent
        def initialize(open:, currency_symbol:)
          @open = open
          @currency_symbol = currency_symbol
        end
      end
    end
  end
end
