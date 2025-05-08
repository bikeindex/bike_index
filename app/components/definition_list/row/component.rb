# frozen_string_literal: true

module DefinitionList::Row
  class Component < ApplicationComponent
    PERMITTED_KINDS = %i[full_width].freeze

    def initialize(label:, value: nil, render_with_no_value: false, kind: nil)
      @label = label
      @value = value
      @render_with_no_value = render_with_no_value
      @kind = kind.to_sym if PERMITTED_KINDS.include?(kind&.to_sym)
    end

    def render?
      return true if @render_with_no_value

      @value.present?
    end

    private

    def wrapper_classes
      if @kind == :full_width
        "tw:col-span-full tw:pt-4"
      else
        "tw:pt-3 tw:items-center tw:@sm:flex tw:@sm:gap-x-2 tw:@sm:pt-1"
      end + " tw:leading-tight"
    end

    def dt_classes
      if @kind == :full_width
        ""
      else
        "tw:@sm:text-right tw:@sm:w-1/4 tw:min-w-[100px]"
      end + " tw:text-sm tw:leading-none tw:opacity-65 tw:font-bold!"
    end
  end
end
