# frozen_string_literal: true

module Form
  module FileUpload
    class Component < ApplicationComponent
      def initialize(form_builder:, attribute:, html_options: {})
        @form_builder = form_builder
        @attribute = attribute
        @html_options = {class: "twinput tw:cursor-pointer"}.merge(html_options)
      end

      def call
        @form_builder.file_field(@attribute, @html_options)
      end
    end
  end
end
