# frozen_string_literal: true

module Atoms
  module Org
    module OriginDisplay
      class Component < ApplicationComponent
        # The sidecar copy reads lowercase - title case in a value is a proper name
        def initialize(ownership:)
          @creation_kind = ownership&.creation_kind
        end

        def render?
          @creation_kind.present?
        end

        def call
          safe_join([translation("labels.#{@creation_kind}"),
            render(UI::Tooltip::Component.new(text: translation("descriptions.#{@creation_kind}")))], " ")
        end
      end
    end
  end
end
