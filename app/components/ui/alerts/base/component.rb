# frozen_string_literal: true

module UI
  module Alerts
    module Base
      class Component < ApplicationComponent
        TEXT_CLASSES = {
          notice: "tw:text-blue-800 tw:dark:text-blue-400",
          error: "tw:text-red-800 tw:dark:text-red-400",
          warning: "tw:text-yellow-800 tw:dark:text-yellow-400",
          success: "tw:text-green-800 tw:dark:text-green-400",
          purple: "tw:text-purple-800 tw:dark:text-purple-400"
        }.freeze
        KINDS = TEXT_CLASSES.keys.freeze

        # icon: rendered markup, e.g. inline_svg_tag("icons/envelope.svg", class: "tw:h-4 tw:w-4") -
        # replaces the default info icon
        def initialize(text: nil, header: nil, kind: :notice, dismissable: false, margin_classes: "tw:mb-4", icon: nil,
          default_header_color: false)
          @text = text
          @header = header
          @kind = normalized_kind(kind)
          @dismissable = dismissable
          @margin_classes = margin_classes
          @icon = icon
          @default_header_color = default_header_color
        end

        private

        # What a screen reader reads in place of the icon. :purple names a color rather
        # than a meaning, so it announces the meaning it actually carries
        def announcement
          translation((@kind == :purple) ? ".info" : ".#{@kind}")
        end

        def normalized_kind(kind)
          return kind.to_sym if KINDS.include?(kind&.to_sym)

          unless Rails.env.production?
            raise ArgumentError, "unknown kind #{kind.inspect}, expected one of: #{KINDS.join(", ")}"
          end

          Honeybadger.notify("Unknown alert kind", {error_class: self.class.to_s, context: {kind:}})
          KINDS.first
        end

        # Give the float the line-height of the line it shares, so it centers on that
        # line alone -- taller for a header
        def icon_classes
          @header.present? ? "tw:h-7" : "tw:h-6"
        end

        def default_icon
          (@kind == :error) ? "icons/exclamation-triangle.svg" : "icons/info.svg"
        end

        def color_classes
          case @kind
          when :notice
            "#{text_color_classes} tw:bg-blue-50 tw:dark:bg-blue-950 tw:border-blue-300 tw:dark:border-blue-800"
          when :error
            "#{text_color_classes} tw:bg-red-50 tw:dark:bg-red-950 tw:border-red-300 tw:dark:border-red-800"
          when :warning
            "#{text_color_classes} tw:bg-yellow-50 tw:dark:bg-yellow-950 tw:border-yellow-300 tw:dark:border-yellow-800"
          when :success
            "#{text_color_classes} tw:bg-green-50 tw:dark:bg-green-950 tw:border-green-300 tw:dark:border-green-800"
          when :purple
            "#{text_color_classes} tw:bg-purple-50 tw:dark:bg-purple-950 tw:border-purple-300 tw:dark:border-purple-800"
          end
        end

        def text_color_classes
          TEXT_CLASSES[@kind]
        end

        def header_color_classes
          @default_header_color ? "tw:twtext-color" : text_color_classes
        end

        def dismissable_color_classes
          case @kind
          when :notice
            "tw:bg-blue-50 tw:focus:ring-blue-400 tw:hover:bg-blue-200 tw:dark:bg-blue-950 tw:dark:hover:bg-blue-900"
          when :error
            "tw:bg-red-50 tw:focus:ring-red-400 tw:hover:bg-red-200 tw:dark:bg-red-950 tw:dark:hover:bg-red-900"
          when :warning
            "tw:bg-yellow-50 tw:focus:ring-yellow-400 tw:hover:bg-yellow-200 tw:dark:bg-yellow-950 tw:dark:hover:bg-yellow-900"
          when :success
            "tw:bg-green-50 tw:focus:ring-green-400 tw:hover:bg-green-200 tw:dark:bg-green-950 tw:dark:hover:bg-green-900"
          when :purple
            "tw:bg-purple-50 tw:focus:ring-purple-400 tw:hover:bg-purple-200 tw:dark:bg-purple-950 tw:dark:hover:bg-purple-900"
          end
        end
      end
    end
  end
end
