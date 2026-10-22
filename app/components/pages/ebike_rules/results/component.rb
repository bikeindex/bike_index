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
        OUT_OF_CLASS_NOTES = %i[class_3_speed_with_throttle throttle_with_class_3_assist].freeze
        NAME_CLASSES = "tw:mt-1 tw:font-header tw:text-[clamp(22px,3vw,26px)] tw:leading-tight tw:font-extrabold"

        def initialize(lookup:)
          @bike = lookup.bike
          @state = lookup.place
          @us = lookup.us?
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
          when :green then @us ? green_headline(name, state) : translation(".green_headline_law", name:, state:, law: @law[:name])
          when :yellow then @us ? yellow_headline(name, state) : metric_yellow_headline(name, state)
          when :red
            # a hand-entered bike's name is "e-bike", which this headline says it isn't
            @bike.manual? ? translation(".red_headline_manual", state:) : translation(".red_headline", name:, state:)
          else translation(".gray_headline", state:)
          end
        end

        def green_headline(name, state)
          if optional_clause.present?
            translation(".green_headline_optional", name:, state:, n: class_numbers, optional: optional_clause)
          else
            translation(".green_headline", name:, state:, n: class_numbers)
          end
        end

        def yellow_headline(name, state)
          if without_throttle?
            translation(".yellow_headline_without_throttle", name:, state:, n: class_numbers)
          elsif @bike.e_bike_class && optional_clause.present?
            translation(".yellow_headline_optional", name:, state:, n: class_numbers, optional: optional_clause, count: rule_count(:check))
          elsif @bike.e_bike_class
            translation(".yellow_headline", name:, state:, n: class_numbers, count: rule_count(:check))
          else
            translation(".yellow_headline_class_unknown", name:, state:, count: rule_count(:check))
          end
        end

        # A motor vehicle's law may still leave it legal, once it's licensed and registered
        def metric_yellow_headline(name, state)
          law = @law[:name]
          if without_throttle?
            translation(".yellow_headline_law_without_throttle", name:, state:, law:)
          elsif @law[:motor_vehicle]
            translation(".yellow_headline_motor_vehicle_law", name:, state:, law:, count: rule_count(:check))
          else
            translation(".yellow_headline_law", name:, state:, law:, count: rule_count(:check))
          end
        end

        def class_numbers = @bike.stock_e_bike_classes.to_sentence

        # Legal but with its optional throttle, which the headline says rather than a rule to check under it
        def without_throttle? = @rules.select { it[:status] == :check }.map { it[:note] } == [:optional_throttle_not_allowed]

        # [class, the optional mode that alone brings it] by class. In no class here, the e-moto's alone, and in none
        # with an optional throttle, its classes but the throttle's, then the e-moto's with the throttle's caption, each
        # e-moto's with the state's out of class marker. Sold in no class the state recognizes, as a Class 3 in New Jersey,
        # the e-moto's alone, under the general marker
        def tiles
          return [[nil, nil]] if unrecognized_classes?

          out_of_class_id = EbikeRuleServices::StateLaws.out_of_class_id(@state[:abbr]) if @us
          return [[nil, nil, out_of_class_id]] if @bike.out_of_class_under?(@law)

          classes = @bike.e_bike_classes.map { [it, @bike.optional_classes[it]] }
          return classes unless @bike.optionally_out_of_class_under?(@law)

          classes.reject { |_, mode| mode == "throttle" } + [[nil, "throttle", out_of_class_id]]
        end

        def unrecognized_classes? = @law.present? && @bike.e_bike_class.present? && @law[:classes].any? && !@law[:classes].intersect?(@bike.stock_e_bike_classes)

        # "and as Class 2 with its optional throttle", of the optional classes the state recognizes, and not a throttle's
        # where it would put the bike in no class
        def optional_clause
          @optional_clause ||= @bike.optional_classes.filter_map { |n, mode|
            next unless @law[:classes].none? || @law[:classes].include?(n)
            next if mode == "throttle" && @bike.optionally_out_of_class_under?(@law)

            (mode == "throttle") ? translation(".as_class_with_optional_throttle", n:) : translation(".as_class_with_optional_upgrade", n:)
          }.to_sentence
        end

        # A BikeBook model's maker and model fill in the registration it starts
        def register_href
          return new_register_path if @bike.manual?

          new_register_path(manufacturer: @bike.manufacturer_name, frame_model: @bike.model)
        end

        def details
          @details ||= case @verdict
          when :yellow then without_throttle? ? [] : notes(:check)
          when :red then [*notes(:fail), falls_under]
          when :gray then @us ? [gray_detail] : []
          else []
          end
        end

        def gray_detail
          if @bike.e_bike_class
            translation(".gray_detail", name: bike_name, n: class_numbers, state: @state[:name])
          else
            translation(".gray_detail_unclassified", name: bike_name, state: @state[:name])
          end
        end

        def falls_under
          name = other_classification&.dig(:name)
          name ? translation(".falls_under_name", state: @state[:name], name:) : copy[:may_be_moped]
        end

        # The state's own class it falls under instead, which the status lists the rules of
        def other_classification
          return @other_classification if defined?(@other_classification)

          @other_classification = (EbikeRuleServices::StateLaws.other_classification(@state[:abbr], @bike.e_vehicle_classifications) if @us)
        end

        # The copy that names a state, and Canada's in its place
        def copy
          @copy ||= if @us
            {your_state: translation(".your_state"), still_reviewing_body: translation(".still_reviewing_body"),
             may_be_moped: translation(".may_be_moped")}
          else
            {your_state: translation(".your_province"), still_reviewing_body: translation(".still_reviewing_province_body"),
             may_be_moped: translation(".may_be_moped_canada")}
          end
        end

        def source
          link = link_to(translation(".bikebook_name"), ReadableQuery.path(bikebook_path, vehicle_models: @law[:id]), class: "twlink")
          @us ? translation(".source_html", link:) : translation(".law_source_html", link:)
        end

        def rule_count(status) = @rules.count { it[:status] == status }

        # A Class 3's assist with a throttle is why its classes aren't permitted, which their note already says
        def notes(status) = @rules.select { it[:status] == status && OUT_OF_CLASS_NOTES.exclude?(it[:note]) }.map { safe_join([note(it), "."]) }

        def subline
          @bike.manual? ? translation(".manually_entered") : translation(".model_year", year: @bike.first_year)
        end

        def specs
          [
            [translation(".motor"), @bike.watts && translation(".watts_html", watts: number_display(@bike.watts))],
            [translation(".top_speed"), top_speed_display],
            [translation(".throttle"), throttle_display]
          ]
        end

        def top_speed_display
          return metric_top_speed_display unless @us

          if @bike.assists_past_mph
            translation(".over_mph_html", mph: number_display(@bike.assists_past_mph))
          elsif @bike.top_assist_mph
            translation(".mph_html", mph: number_display(@bike.top_assist_mph))
          end
        end

        def metric_top_speed_display
          if @bike.assists_past_kmh
            translation(".over_kmh_html", kmh: number_display(@bike.assists_past_kmh))
          elsif @bike.top_assist_kmh
            translation(".kmh_html", kmh: number_display(@bike.top_assist_kmh))
          end
        end

        def throttle_display
          return translation(".answer_no") unless @bike.throttle
          return metric_throttle_display unless @us

          mph = @bike.throttle_mph && number_display(@bike.throttle_mph)
          if @bike.optional_throttle?
            mph ? translation(".optional_to_html", mph:) : translation(".answer_optional")
          else
            mph ? translation(".yes_to_html", mph:) : translation(".answer_yes")
          end
        end

        def metric_throttle_display
          kmh = @bike.throttle_kmh && number_display(@bike.throttle_kmh)
          if @bike.optional_throttle?
            kmh ? translation(".optional_to_kmh_html", kmh:) : translation(".answer_optional")
          else
            kmh ? translation(".yes_to_kmh_html", kmh:) : translation(".answer_yes")
          end
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
          # classes are names rather than quantities, and a law's date a calendar day
          args = row[:args].to_h do |key, value|
            if key == :e_bike_classes
              [:n, value.to_sentence]
            elsif value.is_a?(Date)
              [key, l(value, format: :long)]
            else
              [key, number_display(value)]
            end
          end
          (metric_note(row[:note], args) if @law[:metric]) || us_note(row, args)
        end

        # nil where it reads the same as a US law's
        def metric_note(note, args)
          case note
          when :no_e_bike_category then translation(".no_e_bike_category")
          when :watts_to_check then translation(".watts_to_check_html", **args)
          when :no_watt_cap then translation(".no_watt_cap_in_law")
          when :speed_within_cap then translation(".speed_within_cap_kmh_html", **args)
          when :speed_over_cap then translation(".speed_over_cap_kmh_html", **args)
          when :speed_past_cap then translation(".speed_past_cap_kmh_html", **args)
          when :speed_past then translation(".speed_past_kmh_html", **args)
          when :speed_to_check then translation(".speed_to_check_kmh_html", **args)
          when :no_speed_cap then translation(".no_speed_cap_in_law")
          when :throttle_not_allowed then translation(".throttle_not_allowed_in_law")
          when :throttle_not_stated then translation(".throttle_not_stated_in_law")
          when :throttle_allowed then translation(".throttle_allowed_in_law")
          end
        end

        def us_note(row, args)
          case row[:note]
          when :classes_recognized then translation(".classes_recognized", count: row[:args][:e_bike_classes].size, **args)
          when :classes_not_recognized
            translation(".classes_not_recognized_in", count: row[:args][:e_bike_classes].size, state: @state[:name], **args)
          when :optional_classes_not_recognized
            translation(".optional_classes_not_recognized_in", count: row[:args][:e_bike_classes].size, state: @state[:name], **args)
          when :optional_throttle_not_allowed then translation(".optional_throttle_not_allowed")
          when :classes_not_permitted
            translation(".classes_not_permitted", classes: row[:args][:e_bike_classes].map { translation(".class_n", n: it) }.to_sentence)
          when :not_classified then translation(".not_classified")
          when :class_unknown then translation(".class_unknown_check_label")
          when :own_classes then translation(".own_classes")
          when :classes_start_on then translation(".classes_start_on", **args)
          when :limits_start_on then translation(".limits_start_on", **args)
          when :watts_within_cap then translation(".watts_within_cap_html", **args)
          when :watts_over_cap then translation(".watts_over_cap_html", **args)
          when :watts_not_provided then translation(".watts_not_provided")
          when :no_watt_cap then translation(".no_watt_cap")
          when :speed_within_cap then translation(".speed_within_cap_html", **args)
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
          else translation(".has_throttle")
          end
        end
      end
    end
  end
end
