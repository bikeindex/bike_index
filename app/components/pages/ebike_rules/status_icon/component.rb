# frozen_string_literal: true

module Pages
  module EbikeRules
    module StatusIcon
      # A status disc, whose icon's shape says what its color does
      class Component < ApplicationComponent
        STATUSES = {
          pass: {classes: "tw:bg-[#2e8b57] tw:text-white", icon: "icons/check.svg"},
          check: {classes: "tw:bg-[#ffd660] tw:text-slate-900", icon: "icons/exclamation.svg"},
          fail: {classes: "tw:bg-[#cc0000] tw:text-white", icon: "icons/x.svg"},
          info: {classes: "tw:bg-gray-200 tw:text-gray-700", icon: "icons/info-i.svg"},
          unknown: {classes: "tw:bg-gray-600 tw:text-white", icon: "icons/question-mark.svg"}
        }.freeze

        SIZES = {
          sm: {disc: "tw:size-5.5", icon: "tw:size-3.25"},
          md: {disc: "tw:size-7", icon: "tw:size-4"},
          lg: {disc: "tw:size-11", icon: "tw:size-6"}
        }.freeze

        # label: what the status means, for a disc without words beside it saying so
        def initialize(status:, size: :sm, label: nil)
          @status = STATUSES.fetch(status)
          @size = SIZES.fetch(size)
          @label = label
        end

        def call
          tag.span(class: "#{@size[:disc]} #{@status[:classes]} tw:flex tw:flex-none tw:items-center tw:justify-center tw:rounded-full",
            role: ("img" if @label), aria: @label ? {label: @label} : {hidden: true}) do
            helpers.inline_svg_tag(@status[:icon], class: "#{@size[:icon]} tw:stroke-[3.5]", aria_hidden: true)
          end
        end
      end
    end
  end
end
