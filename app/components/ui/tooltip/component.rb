# frozen_string_literal: true

module UI::Tooltip
  class Component < ApplicationComponent
    renders_one :body

    def initialize(text: nil)
      @text = text
    end

    private

    def tooltip_body
      body? ? body : @text
    end

    def tooltip_id
      @tooltip_id ||= "tooltip-#{SecureRandom.hex(4)}"
    end
  end
end
