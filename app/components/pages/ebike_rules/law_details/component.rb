# frozen_string_literal: true

module Pages
  module EbikeRules
    module LawDetails
      # A state law's restrictions and sources, as Bike Book records them
      class Component < ApplicationComponent
        def initialize(law:)
          @law = law
        end
      end
    end
  end
end
