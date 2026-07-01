# frozen_string_literal: true

module Form
  module FileUpload
    class Component < ApplicationComponent
      def initialize(form_builder:, attribute:, accept: nil, button_text: "Choose file", placeholder: "No file chosen", html_options: {})
        @form_builder = form_builder
        @attribute = attribute
        @button_text = button_text
        @placeholder = placeholder
        @html_options = {
          class: "tw:peer tw:sr-only",
          accept: Array(accept).join(",").presence,
          data: {"form--file-upload-target": "input", action: "form--file-upload#display"}
        }.merge(html_options)

        # Style the label as a UI::Button; the focus ring is driven by the peer (sr-only) input.
        @label_classes = UI::Button::Component.build_classes(color: :secondary, size: :md, html_class: "tw:whitespace-nowrap tw:peer-focus-visible:ring-3 tw:peer-focus-visible:ring-blue-500/40")
      end
    end
  end
end
