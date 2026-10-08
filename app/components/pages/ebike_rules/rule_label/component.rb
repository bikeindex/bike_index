# frozen_string_literal: true

module Pages
  module EbikeRules
    module RuleLabel
      class Component < ApplicationComponent
        def initialize(id:)
          @id = id
        end

        # escaped here, since a plain translation renders as HTML-unsafe
        def call = safe_join([label])

        private

        def label
          case @id
          when :classes then translation(".classes")
          when :power then translation(".power")
          when :speed then translation(".speed")
          else translation(".throttle")
          end
        end
      end
    end
  end
end
