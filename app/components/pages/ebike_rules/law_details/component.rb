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

        # a source that isn't a web page isn't a link
        def sources = @law[:sources].grep(%r{\Ahttps?://})
      end
    end
  end
end
