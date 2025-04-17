# frozen_string_literal: true

module UserTextBlockDisplay
  class Component < ApplicationComponent
    def initialize(text:)
      @text = text.strip
    end
  end
end
