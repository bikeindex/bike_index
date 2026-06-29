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
          class: "tw:absolute tw:inset-0 tw:size-full tw:cursor-pointer tw:opacity-0",
          accept: Array(accept).join(",").presence,
          data: {"form--file-upload-target": "input", action: "form--file-upload#display"}
        }.merge(html_options)
      end
    end
  end
end
