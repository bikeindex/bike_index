# frozen_string_literal: true

module Atoms
  module Org
    module OriginDisplay
      class Component < ApplicationComponent
        def initialize(ownership:)
          @ownership = ownership
        end

        def render?
          creation_kind.present?
        end

        def call
          safe_join([translation("labels.#{creation_kind}"),
            render(UI::Tooltip::Component.new(text: translation("descriptions.#{creation_kind}")))], " ")
        end

        private

        def creation_kind
          @ownership&.creation_kind
        end
      end
    end
  end
end
