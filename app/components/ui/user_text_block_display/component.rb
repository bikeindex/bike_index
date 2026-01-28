# frozen_string_literal: true

module UI::UserTextBlockDisplay
  class Component < ApplicationComponent
    def initialize(text: nil, additional_classes: nil, max_height_class: "tw:max-h-80")
      @text = text&.strip
      @additional_classes = additional_classes || ""
      @additional_classes += " #{max_height_class}"
      @overflow_class = max_height_class.present? ? "tw:overflow-y-auto" : ""
    end

    def render?
      @text.present?
    end
  end
end
