# frozen_string_literal: true

module Pages
  module EbikeRules
    module Reasons
      # Why the lookup's bike isn't an e-bike in its state, or is one only without its optional throttle, in the frame
      # Bike Book loads under a model's classes. Without a state, why it's an e-moto: the US classes' limits it's past.
      # Empty for an e-bike
      class Component < ApplicationComponent
        FRAME_ID = "ebike-rules-reasons"
        US_CLASSES = {classes: [1, 2, 3], mph: 28, watt_cap: 750, throttle: true}.freeze

        def initialize(lookup:, frame_id:)
          @lookup = lookup
          @frame_id = frame_id
        end

        def call
          helpers.turbo_frame_tag(@frame_id) do
            tag.p(safe_join(reasons, " "), class: "tw:mt-2 tw:text-sm tw:text-gray-700 tw:dark:text-gray-300") if reasons.any?
          end
        end

        private

        def reasons
          @reasons ||= rows.map { safe_join([render(Pages::EbikeRules::RuleNote::Component.new(row: it, law:, bike: @lookup.bike, state: @lookup.place)), "."]) }
        end

        # The tiles already say it's in no class, and its speed's row why a Class 3's throttle isn't permitted
        def rows
          bike = @lookup.bike
          return [] if bike.nil? || law.nil? || (@lookup.place ? !@lookup.result? : bike.e_bike_class)

          rules = EbikeRuleServices::Evaluator.rules(law:, bike:)
          shown = if EbikeRuleServices::Evaluator.verdict(rules) == :red
            rules.select { it[:status] == :fail }
          else
            rules.select { it[:note] == :optional_throttle_not_allowed }
          end
          shown.reject { %i[not_classified throttle_with_class_3_assist].include?(it[:note]) }
        end

        def law = @law ||= @lookup.place ? @lookup.law : US_CLASSES
      end
    end
  end
end
