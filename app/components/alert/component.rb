# frozen_string_literal: true

# should replace _revised_messages.html.haml
module Alert
  class Component < ApplicationComponent
    KINDS = %i[notice error warning success]
    # TODO: Should this convert danger>error, notice>warning? Do we need those anymore, from some bootstrap thing?

    # NOTE: you can pass arbitrary classes in via margin_classes, but that's not ideal (they might conflict, etc)
    def initialize(text: nil, kind: nil, dismissable: false, margin_classes: "tw:mb-4")
      @text = text
      @kind = if KINDS.include?(kind&.to_sym)
        kind&.to_sym
      else
        KINDS.first
      end
      @dismissable = dismissable
      @margin_classes = margin_classes
    end

    private

    def color_classes
      case @kind
      when :notice
        "tw:text-blue-800 tw:bg-blue-50 tw:dark:bg-gray-800 tw:dark:text-blue-400 " \
        "tw:border-blue-300 tw:dark:border-blue-800"
      when :error
        "tw:text-red-800 tw:bg-red-50 tw:dark:bg-gray-800 tw:dark:text-red-400 " \
        "tw:border-red-300 tw:dark:border-red-800"
      when :warning
        "tw:text-yellow-800 tw:bg-yellow-50 tw:dark:bg-gray-800 tw:dark:text-yellow-400 " \
        "tw:border-yellow-300 tw:dark:border-yellow-800"
      when :success
        "tw:text-green-800 tw:bg-green-50 tw:dark:bg-gray-800 tw:dark:text-green-400 " \
        "tw:border-green-300 tw:dark:border-green-800"
      end
    end

    def dismissable_color_classes
      case @kind
      when :notice
        "tw:bg-blue-50 tw:focus:ring-blue-400 tw:hover:bg-blue-200 tw:dark:bg-gray-800 tw:dark:hover:bg-gray-700"
      when :error
        "tw:bg-red-50 tw:focus:ring-red-400 tw:hover:bg-red-200 tw:dark:bg-gray-800 tw:dark:hover:bg-gray-700"
      when :warning
        "tw:bg-yellow-50 tw:focus:ring-yellow-400 tw:hover:bg-yellow-200 tw:dark:bg-gray-800 tw:dark:hover:bg-gray-700"
      when :success
        "tw:bg-green-50 tw:focus:ring-green-400 tw:hover:bg-green-200 tw:dark:bg-gray-800 tw:dark:hover:bg-gray-700"
      end
    end
  end
end
