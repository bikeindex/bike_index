# frozen_string_literal: true

module UI
  module PeriodSelect
    class Component < ApplicationComponent
      def initialize(period:, start_time:, end_time:, include_future: false, prepend_text: nil)
        @include_future = include_future
        @prepend_text = prepend_text
        @period = period
        @start_time = start_time
        @end_time = end_time
      end

      private

      def period_url(period)
        helpers.url_for(helpers.sortable_search_params.merge(period:))
      end

      def custom_form_classes
        base = "custom-time-selection mt-2 mb-2"
        (@period == "custom") ? base : "#{base} tw:hidden"
      end
    end
  end
end
