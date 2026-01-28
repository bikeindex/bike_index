# frozen_string_literal: true

module UI::LoadingSpinner
  class Component < ApplicationComponent
    def initialize(text:)
      @text = text
    end
  end
end
