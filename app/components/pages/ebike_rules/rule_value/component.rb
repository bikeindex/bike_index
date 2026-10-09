# frozen_string_literal: true

module Pages
  module EbikeRules
    module RuleValue
      # What a state's law sets for one rule
      class Component < ApplicationComponent
        def initialize(law:, id:)
          @law = law
          @id = id
        end

        def call = h(value)

        private

        def value
          case @id
          when :classes then classes
          when :power then @law[:watt_cap] ? translation(".watts_html", watts: number_display(@law[:watt_cap])) : translation(".no_cap")
          when :speed then @law[:mph] ? translation(".mph_html", mph: number_display(@law[:mph])) : translation(".no_cap")
          else @law[:throttle] ? translation(".allowed") : translation(".not_allowed")
          end
        end

        def classes
          return translation(".own_definition", name: @law[:name]) if @law[:classes].none?

          translation(".classes", count: @law[:classes].size, classes: @law[:classes].to_sentence)
        end
      end
    end
  end
end
