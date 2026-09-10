# frozen_string_literal: true

module Atoms
  module Org
    module OriginDisplay
      class Component < ApplicationComponent
        def initialize(ownership:)
          @creation_kind = ownership&.creation_kind
        end

        def render?
          @creation_kind.present?
        end

        def call
          safe_join([Ownership.creation_kind_humanized(@creation_kind),
            render(UI::Tooltip::Component.new(text: Ownership.creation_kind_description(@creation_kind)))], " ")
        end
      end
    end
  end
end
