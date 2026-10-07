# frozen_string_literal: true

module Pages
  module EbikeRules
    module StateReference
      # Every state's e-bike rules, collapsed. All of it renders, so collapsed rules are still in the page
      class Component < ApplicationComponent
        RULE_IDS = %i[classes power speed throttle age helmet paths label].freeze

        private

        def states = ::EbikeRules::StateLaws::STATES.map { it.merge(law: ::EbikeRules::StateLaws.find(it[:abbr])) }

        def on_file_count = ::EbikeRules::StateLaws::LAWS.count

        def rule_label(id)
          case id
          when :classes then translation(".rule_classes")
          when :power then translation(".rule_power")
          when :speed then translation(".rule_speed")
          when :throttle then translation(".rule_throttle")
          when :age then translation(".rule_age")
          when :helmet then translation(".rule_helmet")
          when :paths then translation(".rule_paths")
          else translation(".rule_label")
          end
        end

        def rule_value(law, id)
          return translation(".watts_html", watts: number_display(law[:watt_cap])) if id == :power

          law[:text][id]
        end
      end
    end
  end
end
