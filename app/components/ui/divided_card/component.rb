# frozen_string_literal: true

module UI
  module DividedCard
    # A bordered, rounded card whose direct children are separated by row dividers
    class Component < ApplicationComponent
      def call
        content_tag(:div, content, class: "tw:divide-y tw:divide-gray-200 tw:rounded-xl " \
          "tw:border tw:border-gray-200 tw:bg-white tw:dark:divide-gray-700 " \
          "tw:dark:border-gray-700 tw:dark:bg-gray-800")
      end
    end
  end
end
