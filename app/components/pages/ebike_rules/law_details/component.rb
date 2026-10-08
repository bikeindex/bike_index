# frozen_string_literal: true

module Pages
  module EbikeRules
    module LawDetails
      # A state law's restrictions and sources, as Bike Book records them
      class Component < ApplicationComponent
        def initialize(law:)
          @law = law
        end

        private

        # calendar days, which UI::Time would shift into the viewer's time zone
        def day(date) = l(date, format: :long)

        def dates(restriction)
          starts_on, ends_on = restriction.values_at(:starts_on, :ends_on)
          if starts_on && ends_on
            translation(".from_until", starts_on: day(starts_on), ends_on: day(ends_on))
          elsif starts_on
            translation(".from", date: day(starts_on))
          elsif ends_on
            translation(".until", date: day(ends_on))
          end
        end
      end
    end
  end
end
