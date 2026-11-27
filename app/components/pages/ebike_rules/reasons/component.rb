# frozen_string_literal: true

module Pages
  module EbikeRules
    module Reasons
      # Why the lookup's bike isn't an e-bike in its state, or is one only without its optional throttle, in the frame
      # Bike Book loads beside a model's classes. Without a state, why it's an e-moto: the US classes' limits it's past.
      # Empty for an e-bike
      class Component < ApplicationComponent
        FRAME_ID = "ebike-rules-reasons"

        def initialize(lookup:, frame_id:)
          @lookup = lookup
          @frame_id = frame_id
        end

        def call
          helpers.turbo_frame_tag(@frame_id) do
            reasons.presence&.then { tag.p(safe_join(it, " "), class: "tw:text-sm tw:text-gray-700 tw:dark:text-gray-300") }
          end
        end

        private

        def reasons
          rows.map { safe_join([render(Pages::EbikeRules::RuleNote::Component.new(row: it, law:, bike: @lookup.bike, state: @lookup.place)), "."]) }
        end

        def rows
          bike = @lookup.bike
          return [] unless law && (@lookup.place ? @lookup.result? : bike && !bike.e_bike_class)

          rules = EbikeRuleServices::Evaluator.rules(law:, bike:)
          if EbikeRuleServices::Evaluator.verdict(rules) == :red
            # The tiles already say it's in no class, and its speed's row why a Class 3's throttle isn't permitted
            rules.select { it[:status] == :fail && %i[not_classified throttle_with_class_3_assist].exclude?(it[:note]) }
          else
            rules.select { it[:note] == :optional_throttle_not_allowed }
          end
        end

        def law = @law ||= @lookup.law
      end
    end
  end
end
