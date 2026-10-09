# frozen_string_literal: true

module Atoms
  module Sticker
    # Renders a bike sticker's code as a monospace code block. Pass a BikeSticker,
    # or a raw pretty_code string; url links the code, copyable adds a copy button.
    class Component < ApplicationComponent
      BASE_CLASSES = "tw:font-mono tw:text-sm tw:p-0 tw:bg-transparent tw:text-inherit tw:rounded-none tw:font-semibold"

      def initialize(bike_sticker: nil, pretty_code: nil, url: nil, copyable: false, html_class: nil)
        @pretty_code = pretty_code || bike_sticker&.pretty_code
        @url = url
        @copyable = copyable
        @html_class = html_class
      end

      def render?
        @pretty_code.present?
      end

      def call
        return render(UI::CopyableCode::Component.new(value: @pretty_code, label: translation(".copy_sticker"))) if @copyable
        return code_block if @url.blank?

        link_to(code_block, @url, class: "twlink")
      end

      private

      def code_block
        content_tag(:code, @pretty_code, class: [BASE_CLASSES, @html_class])
      end
    end
  end
end
