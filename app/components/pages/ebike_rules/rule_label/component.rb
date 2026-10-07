# frozen_string_literal: true

module Pages
  module EbikeRules
    module RuleLabel
      class Component < ApplicationComponent
        def initialize(id:)
          @id = id
        end

        def call
          case @id
          when :classes then translation(".classes")
          when :power then translation(".power")
          when :speed then translation(".speed")
          when :throttle then translation(".throttle")
          when :age then translation(".age")
          when :helmet then translation(".helmet")
          when :paths then translation(".paths")
          else translation(".label")
          end
        end
      end
    end
  end
end
