# frozen_string_literal: true

module Search::KindOption
  class Component < ApplicationComponent
    def initialize(option_kind:, option:, option_text:, is_selected:, button_url: nil)
      @option_kind = option_kind
      @option = option
      @option_text = option_text
      @is_selected = is_selected
      @button_url = button_url
    end

    private

    def test_id
      "Search::KindOption-#{@option}"
    end

    def is_button?
      @button_url.present?
    end
  end
end
