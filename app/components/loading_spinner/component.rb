# frozen_string_literal: true

module LoadingSpinner
  class Component < ApplicationComponent
    def initialize(text:)
      @text = text
    end
  end
end
