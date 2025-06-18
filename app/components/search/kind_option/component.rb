# frozen_string_literal: true

module Search::KindOption
  class Component < ApplicationComponent
    def initialize(option_kind:, option:, option_text:, is_selected:, is_button:)
      @option_kind = option_kind
      @option = option
      @option_text = option_text
      @is_selected = is_selected
      @is_button = is_button
    end

    private
  end
end
