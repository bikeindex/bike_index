# frozen_string_literal: true

module UI
  module PeriodSelect
    class Component < ApplicationComponent
      PERIODS = [
        {key: "next_week", prefix: "next", label: "seven_days", future: true},
        {key: "next_month", prefix: "next", label: "thirty_days", future: true},
        {key: "hour", prefix: "past", label: "hour"},
        {key: "day", prefix: "past", label: "day"},
        {key: "week", prefix: "past", label: "seven_days"},
        {key: "month", prefix: "past", label: "thirty_days"},
        {key: "year", prefix: "past", label: "year"},
        {key: "all", prefix: nil, label: "all"}
      ].freeze

      def initialize(period:, start_time:, end_time:, include_future: false, prepend_text: nil)
        @include_future = include_future
        @prepend_text = prepend_text
        @period = period
        @start_time = start_time
        @end_time = end_time
      end

      private

      def visible_periods
        @include_future ? PERIODS : PERIODS.reject { |p| p[:future] }
      end

      def period_button(period_key)
        UI::ButtonLink::Component.new(
          href: period_url(period_key),
          size: :sm,
          active: @period == period_key,
          class: "period-select-standard",
          data: {period: period_key, turbo_action: "advance"}
        )
      end

      def period_url(period)
        helpers.url_for(helpers.sortable_search_params.merge(period:))
      end

      def custom_form_classes
        base = "tw:mt-3 tw:mb-2"
        (@period == "custom") ? base : "#{base} tw:hidden"
      end
    end
  end
end
