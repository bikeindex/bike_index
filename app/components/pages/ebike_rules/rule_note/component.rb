# frozen_string_literal: true

module Pages
  module EbikeRules
    module RuleNote
      # What one of EbikeRuleServices::Evaluator's rows means for the bike, under the `state`'s law
      class Component < ApplicationComponent
        def initialize(row:, law:, bike:, state:)
          @row = row
          @law = law
          @bike = bike
          @state = state
        end

        def call = h((metric_note if @law[:metric]) || us_note)

        private

        # classes are names rather than quantities, and a law's date a calendar day
        def args
          @args ||= @row[:args].to_h do |key, value|
            if key == :e_bike_classes
              [:n, value.to_sentence]
            elsif value.is_a?(Date)
              [key, l(value, format: :long)]
            else
              [key, number_display(value)]
            end
          end
        end

        # nil where it reads the same as a US law's
        def metric_note
          case @row[:note]
          when :no_e_bike_category then translation(".no_e_bike_category")
          when :no_watt_cap then translation(".no_watt_cap_in_law")
          when :speed_within_cap then translation(".speed_within_cap_kmh_html", **args)
          when :speed_over_cap then translation(".speed_over_cap_kmh_html", **args)
          when :speed_past_cap then translation(".speed_past_cap_kmh_html", **args)
          when :speed_past then translation(".speed_past_kmh_html", **args)
          when :throttle_past_cap then translation(".throttle_past_cap_kmh_html", **args)
          when :throttle_past then translation(".throttle_past_kmh_html", **args)
          when :speed_to_check then translation(".speed_to_check_bike_book_kmh_html", **args)
          when :no_speed_cap then translation(".no_speed_cap_in_law")
          when :throttle_not_allowed then translation(".throttle_not_allowed_in_law")
          when :throttle_not_stated then translation(".throttle_not_stated_in_law")
          when :throttle_allowed then translation(".throttle_allowed_in_law")
          end
        end

        def us_note
          case @row[:note]
          when :classes_recognized then translation(".classes_recognized", count: @row[:args][:e_bike_classes].size, **args)
          when :classes_not_recognized
            translation(".classes_not_recognized_in", count: @row[:args][:e_bike_classes].size, state: @state[:name], **args)
          when :optional_classes_not_recognized
            translation(".optional_classes_not_recognized_in", count: @row[:args][:e_bike_classes].size, state: @state[:name], **args)
          when :optional_throttle_not_allowed then translation(".optional_throttle_not_allowed")
          when :classes_not_permitted
            translation(".classes_not_permitted", classes: @row[:args][:e_bike_classes].map { translation(".class_n", n: it) }.to_sentence)
          when :not_classified then translation(".not_classified")
          when :class_unknown then translation(".class_unknown_in_bike_book_label")
          when :own_classes then translation(".own_classes")
          when :classes_start_on then translation(".classes_start_on", **args)
          when :limits_start_on then translation(".limits_start_on", **args)
          when :watts_within_cap then translation(".watts_within_cap_html", **args)
          when :watts_over_cap then translation(".watts_over_cap_html", **args)
          when :watts_to_check then translation(".watts_to_check_html", **args)
          when :watts_not_provided then translation(".watts_not_provided")
          when :no_watt_cap then translation(".no_watt_cap")
          when :speed_within_cap then translation(".speed_within_cap_html", **args)
          when :throttle_speed_within_cap then translation(".throttle_speed_within_cap_html", **args)
          when :throttle_speed_over_cap then translation(".throttle_speed_over_cap_html", **args)
          when :class_3_speed_with_throttle then translation(".class_3_speed_with_throttle_html", **args)
          when :speed_over_cap then translation(".speed_over_cap_html", **args)
          when :speed_past_cap then translation(".speed_past_cap_html", **args)
          when :speed_past then translation(".speed_past_html", **args)
          when :speed_not_provided then translation(".speed_not_provided")
          when :no_speed_cap then translation(".no_speed_cap")
          when :no_throttle then translation(".no_throttle")
          when :throttle_not_allowed then translation(".throttle_not_allowed")
          when :throttle_not_stated then translation(".throttle_not_stated")
          when :class_1_throttle then translation(".class_1_throttle")
          when :throttle_allowed then translation(".throttle_allowed")
          when :throttle_with_class_3_assist then translation(".throttle_with_class_3_assist")
          when :class_3_throttle then translation(".class_3_throttle")
          when :class_3_throttle_within
            if @bike.optional_throttle?
              translation(".class_3_optional_throttle_within_html", **args)
            else
              translation(".class_3_throttle_within_html", **args)
            end
          when :class_3_throttle_over then translation(".class_3_throttle_over_html", **args)
          when :class_3_throttle_past then translation(".class_3_throttle_past")
          else translation(".has_throttle")
          end
        end
      end
    end
  end
end
