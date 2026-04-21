# frozen_string_literal: true

module SearchResults::MultiResultChip
  class Component < ApplicationComponent
    def initialize(serial:, chip_id:, result_count:, error: false)
      @serial = serial
      @chip_id = chip_id
      @result_count = result_count
      @error = error
    end

    def call
      content_tag(:span, id: @chip_id, class: badge_classes) do
        if has_results?
          content_tag(:a, href: "#result_#{@chip_id.delete_prefix("chip_")}", class: serial_span_classes) do
            @serial
          end
        else
          inner = content_tag(:span, @serial, class: "serial-span")
          inner += content_tag(:small, @error ? "error" : translation(".no_results"), class: "tw:block tw:text-2xs tw:leading-none tw:ml-3")
          inner
        end
      end
    end

    private

    def has_results?
      !@error && @result_count > 0
    end

    def serial_span_classes
      "serial-span tw:underline! tw:hover:font-bold! tw:text-emerald-900! tw:py-1 tw:px-2"
    end

    def badge_classes
      color = if @error
        :error
      else
        (has_results? ? :success : :gray)
      end
      b_classes = UI::Badge::Component.badge_classes(color:, size: :md)
      b_classes += " tw:p-0! tw:cursor-pointer" if has_results?
      b_classes
    end
  end
end
