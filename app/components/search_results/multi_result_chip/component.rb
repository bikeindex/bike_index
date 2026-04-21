# frozen_string_literal: true

module SearchResults
  module MultiResultChip
    class Component < ApplicationComponent
      def initialize(serial:, serial_chip_id:, result_count:)
        @serial = serial
        @serial_chip_id = serial_chip_id
        @result_count = result_count
      end

      def call
        content_tag(:span, id: @serial_chip_id, class: badge_classes) do
          if has_results?
            content_tag(:a, href: "#result_#{@serial_chip_id.delete_prefix("chip_")}", class: serial_span_classes) do
              @serial
            end
          else
            inner = content_tag(:span, @serial, class: "serial-span")
            inner += content_tag(:small, translation(".no_results"), class: "tw:block tw:text-2xs tw:leading-none tw:ml-3")
            inner
          end
        end
      end

      private

      def has_results?
        @result_count > 0
      end

      def serial_span_classes
        "serial-span tw:underline! tw:hover:font-bold! tw:text-emerald-900! tw:py-1 tw:px-2"
      end

      def badge_classes
        b_classes = UI::Badge::Component.badge_classes(color: has_results? ? :success : :gray, size: :md)
        b_classes += " tw:p-0! tw:cursor-pointer" if has_results?
        b_classes
      end
    end
  end
end
