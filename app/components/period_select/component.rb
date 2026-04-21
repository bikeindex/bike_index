# frozen_string_literal: true

module PeriodSelect
  class Component < ApplicationComponent
    def initialize(skip_submission: false, include_future: false, prepend_text: nil,
      period: nil, start_time: nil, end_time: nil)
      @skip_submission = skip_submission
      @include_future = include_future
      @prepend_text = prepend_text
      @period = period
      @start_time = start_time
      @end_time = end_time
    end

    def before_render
      @period ||= controller.instance_variable_get(:@period)
      @start_time ||= controller.instance_variable_get(:@start_time)
      @end_time ||= controller.instance_variable_get(:@end_time)
      raise "Must include :set_period for this action" unless @start_time.present?
    end

    private

    def period_url(period)
      helpers.url_for(helpers.sortable_search_params.merge(period:))
    end

    def active_class(period)
      "active" if @period == period
    end

    def custom_form_classes
      base = "custom-time-selection mt-2 mb-2"
      (@period == "custom") ? base : "#{base} tw:hidden"
    end
  end
end
