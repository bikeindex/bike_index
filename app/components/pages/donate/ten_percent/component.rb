# frozen_string_literal: true

module Pages
  module Donate
    module TenPercent
      # For someone whose bike was recovered: donate--ten-percent fills 10% of the value they type into
      # the one-time form's other amount. Goes in Pages::Donate::Form's one_time_intro.
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
