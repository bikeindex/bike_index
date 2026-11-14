# frozen_string_literal: true

module Pages
  module EbikeRules
    module BikeSummary
      # A bike's class tiles, its motor, top speed and throttle, and its electric certification badges: a check's, and
      # Bike Book's Motor & Battery card's, which bikebook/templates/vehicles/bike_summary renders as this does.
      # vehicle_type is its catalog type, which names its classification: any cycle's an e-bike's, and another
      # e-vehicle's its own. specs are [label, value] pairs, a blank value not provided; ul2849 and ul2271 are UlBadge
      # statuses, and others any other certification its record lists
      class Component < ApplicationComponent
        NOT_CYCLES = {"e_scooter" => "scooter", "e_motorcycle" => "motorcycle", "epamd" => "personal mobility"}.freeze

        renders_one :tiles

        def initialize(vehicle_type:, specs:, ul2849:, ul2271:, others: nil)
          @noun = NOT_CYCLES.fetch(vehicle_type, "bike")
          @specs = specs
          @ul2849 = ul2849
          @ul2271 = ul2271
          @others = others
        end

        private

        # The certifications it carries, else the one badge saying neither is known
        def ul_badges
          certified = [[2849, @ul2849], [2271, @ul2271]].select { |_, status| status == :certified }
          certified.presence || [[nil, @ul2849]]
        end
      end
    end
  end
end
