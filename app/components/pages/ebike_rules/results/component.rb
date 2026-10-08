# frozen_string_literal: true

module Pages
  module EbikeRules
    module Results
      class Component < ApplicationComponent
        VERDICTS = {
          green: {classes: "tw:bg-[#e8f5ee] tw:border-[#2e8b57]", icon: :pass},
          yellow: {classes: "tw:bg-[#fff6da] tw:border-[#ffcc33]", icon: :check},
          red: {classes: "tw:bg-[#fdecec] tw:border-[#cc0000]", icon: :fail},
          gray: {classes: "tw:bg-gray-50 tw:border-gray-300", icon: :unknown}
        }.freeze
        EYEBROW_CLASSES = "tw:text-xs tw:font-bold tw:tracking-[.08em] tw:text-gray-600 tw:uppercase tw:dark:text-gray-400"
        NAME_CLASSES = "tw:mt-1 tw:font-header tw:text-[clamp(22px,3vw,26px)] tw:leading-tight tw:font-extrabold"

        def initialize(lookup:)
          @bike = lookup.bike
          @state = lookup.state
          @law = lookup.law
          @rules = @law ? EbikeRuleServices::Evaluator.rules(law: @law, bike: @bike) : []
          @verdict = EbikeRuleServices::Evaluator.verdict(@rules)
        end

        private

        def bike_name = @bike.manual? ? translation(".manual_bike_name") : @bike.make_and_model

        def verdict_label
          case @verdict
          when :green then translation(".legal_to_ride")
          when :yellow then translation(".legal_with_rules")
          when :red then translation(".not_permitted")
          else translation(".rules_not_on_file")
          end
        end

        def headline
          name = bike_name
          state = @state[:name]
          case @verdict
          when :green then translation(".green_headline", name:, state:, n: @bike.e_bike_class)
          when :yellow then translation(".yellow_headline", name:, state:, n: @bike.e_bike_class, count: rule_count(:check))
          when :red then translation(".red_headline", name:, state:)
          else translation(".gray_headline", state:)
          end
        end

        def details
          @details ||= case @verdict
          when :yellow then notes(:check)
          when :red then [*notes(:fail), other_classification]
          when :gray then [gray_detail]
          else []
          end
        end

        def gray_detail
          if @bike.e_bike_class
            translation(".gray_detail", name: bike_name, n: @bike.e_bike_class, state: @state[:name])
          else
            translation(".gray_detail_unclassified", name: bike_name, state: @state[:name])
          end
        end

        def other_classification
          name = EbikeRuleServices::StateLaws.classification_name(@state[:abbr], @bike.e_vehicle_classifications)
          name ? translation(".falls_under", state: @state[:name], name:) : translation(".may_be_moped")
        end

        def rule_count(status) = @rules.count { it[:status] == status }

        def notes(status) = @rules.select { it[:status] == status }.map { safe_join([note(it), "."]) }

        def subline
          if @bike.manual?
            translation(".entered_manually", n: @bike.e_bike_class)
          else
            translation(".bikebook_model", year: @bike.first_year)
          end
        end

        def specs
          [
            [translation(".motor"), @bike.watts && translation(".watts_html", watts: number_display(@bike.watts))],
            [translation(".top_speed"), @bike.top_assist_mph && translation(".mph_html", mph: number_display(@bike.top_assist_mph))],
            [translation(".throttle"), throttle_display]
          ]
        end

        def throttle_display
          return translation(".answer_no") unless @bike.throttle

          @bike.throttle_mph ? translation(".yes_to_html", mph: number_display(@bike.throttle_mph)) : translation(".answer_yes")
        end

        def status_label(status)
          case status
          when :pass then translation(".meets_rule")
          when :check then translation(".rule_to_check")
          when :fail then translation(".fails_rule")
          else translation(".for_your_information")
          end
        end

        def note(row)
          # a class is a name rather than a quantity, and a law's date a calendar day
          args = row[:args].to_h do |key, value|
            if key == :e_bike_class
              [key, value]
            elsif value.is_a?(Date)
              [key, l(value, format: :long)]
            else
              [key, number_display(value)]
            end
          end
          case row[:note]
          when :class_recognized then translation(".class_recognized", **args)
          when :class_not_recognized then translation(".class_not_recognized", **args)
          when :not_classified then translation(".not_classified")
          when :own_classes then translation(".own_classes")
          when :classes_start_on then translation(".classes_start_on", **args)
          when :limits_start_on then translation(".limits_start_on", **args)
          when :watts_within_cap then translation(".watts_within_cap_html", **args)
          when :watts_over_cap then translation(".watts_over_cap_html", **args)
          when :watts_not_provided then translation(".watts_not_provided")
          when :no_watt_cap then translation(".no_watt_cap")
          when :speed_within_cap then translation(".speed_within_cap_html", **args)
          when :speed_over_cap then translation(".speed_over_cap_html", **args)
          when :speed_not_provided then translation(".speed_not_provided")
          when :no_speed_cap then translation(".no_speed_cap")
          when :no_throttle then translation(".no_throttle")
          when :throttle_not_allowed then translation(".throttle_not_allowed")
          when :class_1_throttle then translation(".class_1_throttle")
          when :throttle_allowed then translation(".throttle_allowed")
          when :class_3_throttle then translation(".class_3_throttle")
          else translation(".has_throttle")
          end
        end

        def share_url = ebike_rules_state_url(@state[:abbr].downcase)
      end
    end
  end
end
