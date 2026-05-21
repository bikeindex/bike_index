# frozen_string_literal: true

module UI
  module ChartAsyncFrame
    # Lazy turbo-frame placeholder for UI::Chart::Component. Reserves the
    # chart's 300px height so the page doesn't shift when chartkick injects
    # its container; the literal `tw:min-h-[300px]` here lets the Tailwind
    # JIT pick the class up from this file.
    class Component < ApplicationComponent
      WRAPPER_CLASSES = "tw:flex tw:min-h-[300px] tw:items-center tw:justify-center"

      def initialize(id:, src: nil, collection: nil)
        @id = id
        @src = src
        @collection = collection
      end

      # Pass `collection:` to suppress the placeholder when there's nothing to
      # chart. Omit it in chart-only wrapper mode so the frame still ships back
      # to clear the spinner if the data emptied between the two requests.
      def render?
        @collection.nil? || @collection.present?
      end

      def call
        if @src
          helpers.turbo_frame_tag(@id, src: @src, loading: :lazy, class: WRAPPER_CLASSES) do
            render(UI::LoadingSpinner::Component.new(text: translation(".loading_chart")))
          end
        else
          helpers.turbo_frame_tag(@id, class: WRAPPER_CLASSES) { content }
        end
      end
    end
  end
end
