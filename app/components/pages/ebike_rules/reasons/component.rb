# frozen_string_literal: true

module Pages
  module EbikeRules
    module Reasons
      # Why the lookup's bike isn't an e-bike in its state, or is one only without its optional throttle, in the frame
      # Bike Book loads under a model's classes. Empty for one that is
      class Component < ApplicationComponent
        FRAME_ID = "ebike-rules-reasons"

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
          return [] unless @lookup.result? && law

          rules = EbikeRuleServices::Evaluator.rules(law:, bike: @lookup.bike)
          shown = if EbikeRuleServices::Evaluator.verdict(rules) == :red
            rules.select { it[:status] == :fail }
          else
            rules.select { it[:note] == :optional_throttle_not_allowed }
          end
          shown.reject { %i[not_classified throttle_with_class_3_assist].include?(it[:note]) }
        end

        def law = @law ||= @lookup.law
      end
    end
  end
end
