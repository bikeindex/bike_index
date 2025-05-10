# frozen_string_literal: true

module UserTextBlockDisplay
  class Component < ApplicationComponent
    def initialize(text: nil)
      @text = text&.strip
    end

    def render?
      @text.present?
    end
  end
end
