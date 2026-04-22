# frozen_string_literal: true

module Admin
  module Badges
    module BikeHiddenExplanation
      class Component < ApplicationComponent
        def initialize(bike:)
          @bike = bike
        end

        def render?
          @bike.present? && !@bike.current?
        end

        def call
          safe_join(
            [deleted_content, user_hidden_content, likely_spam_content, example_content].compact,
            " & "
          )
        end

        private

        def user_hidden_content
          return unless @bike.user_hidden?

          content_tag(:small, "user hidden", class: UI::Alert::Component::TEXT_CLASSES[:notice])
        end

        # BikeVersion can't be example
        def example_content
          return unless @bike.is_a?(Bike) && @bike.example?

          content_tag(:small, "test", title: "example (aka test)", class: error_class)
        end

        # BikeVersion can't be likey spam
        def likely_spam_content
          return unless @bike.is_a?(Bike) && @bike.likely_spam?

          content_tag(:small, "spam", title: "LIKELY spam", class: error_class)
        end

        def deleted_content
          return unless @bike.deleted?

          content_tag(:small,
            content_tag(:span, "deleted: ") +
              content_tag(:span, l(@bike.deleted_at, format: :convert_time), class: "localizeTime"),
            class: UI::Alert::Component::TEXT_CLASSES[:warning])
        end

        def error_class
          UI::Alert::Component::TEXT_CLASSES[:error]
        end
      end
    end
  end
end
