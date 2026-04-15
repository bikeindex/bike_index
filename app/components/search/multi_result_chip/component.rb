# frozen_string_literal: true

module Search::MultiResultChip
  class Component < ApplicationComponent
    def initialize(serial:, serial_chip_id:, result_count:)
      @serial = serial
      @serial_chip_id = serial_chip_id
      @result_count = result_count
    end

    def call
      tag = has_results? ? :a : :span
      opts = {id: @serial_chip_id, class: badge_classes}
      opts[:href] = "#result_#{@serial_chip_id.delete_prefix("chip_")}" if tag == :a
      content_tag(tag, **opts) do
        inner = content_tag(:span, @serial, class: serial_span_classes)
        inner += content_tag(:small, translation(".no_results"), class: "tw:block tw:text-2xs tw:leading-none tw:ml-3") unless has_results?
        inner
      end
    end

    private

    def has_results?
      @result_count > 0
    end

    def serial_span_classes
      return "serial-span" unless has_results?
      "serial-span tw:underline tw:hover:font-bold!"
    end

    def badge_classes
      b_classes = UI::Badge::Component.badge_classes(color: has_results? ? :success : :gray, size: :md)
      b_classes += " tw:cursor-pointer" if has_results?
      b_classes
    end
  end
end
