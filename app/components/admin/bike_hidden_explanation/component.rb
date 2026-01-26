# frozen_string_literal: true

module Admin::BikeHiddenExplanation
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

      content_tag(:small, "user hidden", class: Alert::Component::TEXT_CLASSES[:notice])
    end

    def example_content
      return unless @bike.example?

      content_tag(:small, "test", title: "example (aka test)", class: error_class)
    end

    def likely_spam_content
      return unless @bike.likely_spam?

      content_tag(:small, "spam", title: "LIKELY spam", class: error_class)
    end

    def deleted_content
      return unless @bike.deleted?

      content_tag(:small,
        content_tag(:span, "deleted: ") +
          content_tag(:span, l(@bike.deleted_at, format: :convert_time), class: "localizeTime"),
        class: Alert::Component::TEXT_CLASSES[:warning])
    end

    def error_class
      Alert::Component::TEXT_CLASSES[:error]
    end
  end
end
