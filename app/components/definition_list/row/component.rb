# frozen_string_literal: true

module DefinitionList::Row
  class Component < ApplicationComponent
    def initialize(label:, value: nil, render_with_no_value: false)
      @label = label
      @value = value
      @render_with_no_value = render_with_no_value
    end

    private

    def render?
      return true if @render_with_no_value

      @value.present?
    end
  end
end
