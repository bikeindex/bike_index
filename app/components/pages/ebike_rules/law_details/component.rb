# frozen_string_literal: true

module Pages
  module EbikeRules
    module LawDetails
      # A state law's restrictions and sources, as Bike Book records them
      class Component < ApplicationComponent
        # A law's dates are calendar days, which UI::Time would shift into the viewer's time zone
        DATE_FORMAT = "%B %-d, %Y"

        def initialize(law:)
          @law = law
        end

        private

        def day(date) = l(date, format: DATE_FORMAT)
      end
    end
  end
end
