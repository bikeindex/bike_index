# frozen_string_literal: true

module Search::ResultViewSelect
  class Component < ApplicationComponent
    def initialize(result_view: nil)
      @selected_result_view = SearchResults::Container::Component.permitted_result_view(result_view)
    end

    private

    def selected?(option)
      @selected_result_view == option
    end

    def label_classes
      "tw:cursor-pointer tw:p-2 tw:rounded tw:block tw:has-checked:bg-gray-100 " \
      "tw:has-checked:dark:bg-gray-800 tw:border tw:border-gray-200 tw:dark:border-gray-600"
    end
  end
end
