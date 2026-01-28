# frozen_string_literal: true

module UI::Card
  class Component < ApplicationComponent
    def initialize(additional_classes: nil, shadow: false)
      @additional_classes = additional_classes || ""
      @additional_classes += " tw:shadow-sm" if shadow
    end

    private

    def card_classes
      "tw:p-4 tw:bg-white tw:border tw:border-gray-200 tw:rounded-sm " \
      "tw:dark:bg-gray-800 tw:dark:border-gray-700 " + @additional_classes
    end
  end
end
