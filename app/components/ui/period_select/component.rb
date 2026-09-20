# frozen_string_literal: true

module UI
  module PeriodSelect
    class Component < ApplicationComponent
      # Template Dependency: UI::ButtonGroup::Component, UI::Forms::RadioButtonGroup::Component
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

      # What a time_range_column reads as in prose - "created", "subscription ends"
      def self.column_label(time_range_column)
        time_range_column.to_s.delete_suffix("_at").humanize.downcase
          .sub(/(request|start|end)\z/, "request" => "requested", "start" => "starts", "end" => "ends")
      end

      # What the selected period's button reads, for a caller naming the period elsewhere
      def self.period_label(period)
        entry = PERIODS.find { it[:key] == period.to_s } || {label: "custom"}
        [entry[:prefix], entry[:label]].compact
          .map { I18n.t("components.ui.period_select.#{it}") }.join(" ")
      end

      # form/data: as UI::Forms::RadioButtonGroup takes them - the periods become that form's
      # radios rather than links, so a search carries the period without a page of their own
      def initialize(period:, start_time:, end_time:, sortable_search_params: {}, include_future: false,
        prepend_text: nil, form: nil, data: {})
        @form = form
        @data = data
        @include_future = include_future
        @prepend_text = prepend_text
        @period = period
        @start_time = start_time
        @end_time = end_time
        @sortable_search_params = sortable_search_params
      end

      private

      # The row a chip group lays out, so the two line up where they're stacked
      def row_classes
        "text-right #{UI::ButtonGroup::Component.group_classes(kind: :button, full_width: false)} tw:justify-end"
      end

      def visible_periods
        @include_future ? PERIODS : PERIODS.reject { |p| p[:future] }
      end

      def period_button(period_key)
        UI::ButtonLink::Component.new(
          href: period_url(period_key),
          size: :sm,
          active: @period == period_key,
          html_class: period_button_class,
          data: {period: period_key, turbo_action: "advance"}
        )
      end

      # The chips share the row with the custom button, so they're rendered here rather than
      # as a group of their own, which would wrap as one
      def period_radio(period)
        tag.label(class: UI::Forms::RadioButtonGroup::Component::CHIP_CLASSES) do
          radio_button_tag("period", period[:key], @period == period[:key],
            class: "tw:sr-only", form: @form, data: @data) + tag.span(period_button_label(period))
        end
      end

      # The prefix drops below md, where the row has no room for it
      def period_button_label(period)
        safe_join([(tag.span(translation(".#{period[:prefix]}"), class: "d-none d-md-inline") if period[:prefix]),
          " ", translation(".#{period[:label]}")].compact)
      end

      # Sized to whatever sits beside it: the radio chips are UI::ButtonGroup's default
      def custom_button
        UI::Button::Component.new(text: translation(".custom"), active: @period == "custom",
          size: @form ? :md : :sm, html_class: (period_button_class unless @form),
          data: {period: "custom", action: "click->ui--collapse#toggle"})
      end

      def period_button_class
        base = "tw:px-1.5! tw:sm:px-2.5! tw:transition-opacity tw:duration-500"
        (@period == "custom") ? "#{base} tw:opacity-60" : base
      end

      def period_url(period)
        helpers.url_for(@sortable_search_params.merge(period:))
      end

      def custom_form_classes
        base = "tw:mt-3 tw:mb-2"
        (@period == "custom") ? base : "#{base} tw:hidden"
      end
    end
  end
end
