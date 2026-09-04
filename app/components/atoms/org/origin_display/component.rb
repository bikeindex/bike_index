# frozen_string_literal: true

module Atoms
  module Org
    module OriginDisplay
      class Component < ApplicationComponent
        # component.en.yml reads lowercase - title case in a value is a proper name

        class << self
          def creation_kind_humanized(creation_kind) = copy("labels", creation_kind)

          def creation_kind_description(creation_kind) = copy("descriptions", creation_kind)

          private

          # Blank passes through, but an unknown kind raises - component_spec asserts a
          # label and a description for every kind the enums produce
          def copy(group, creation_kind)
            return if creation_kind.blank?

            I18n.t("#{group}.#{creation_kind}", scope: component_translation_scope)
          end
        end

        def initialize(ownership:)
          @creation_kind = ownership&.creation_kind
        end

        def render?
          @creation_kind.present?
        end

        def call
          safe_join([self.class.creation_kind_humanized(@creation_kind),
            render(UI::Tooltip::Component.new(text: self.class.creation_kind_description(@creation_kind)))], " ")
        end
      end
    end
  end
end
