# frozen_string_literal: true

module UI
  module ChartAsyncFrame
    # Lazy turbo-frame placeholder for UI::Chart::Component. Reserves the
    # chart's 300px height so the page doesn't shift when chartkick injects
    # its container; the literal `tw:min-h-[300px]` here lets the Tailwind
    # JIT pick the class up from this file.
    class Component < ApplicationComponent
      WRAPPER_CLASSES = "tw:flex tw:min-h-[300px] tw:items-center tw:justify-center"

      def initialize(id:, src: nil, chart: nil)
        @id = id
        @src = src
        @chart = chart
      end

      def call
        if @src
          helpers.turbo_frame_tag(@id, src: @src, loading: :lazy, class: WRAPPER_CLASSES) do
            render(UI::LoadingSpinner::Component.new(text: translation(".loading_chart")))
          end
        else
          helpers.turbo_frame_tag(@id, class: WRAPPER_CLASSES) do
            render(@chart) if @chart
          end
        end
      end
    end
  end
end
