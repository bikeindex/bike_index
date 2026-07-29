# frozen_string_literal: true

module UI
  module Forms
    module Email
      # An email field that offers a correction for a mistyped domain --
      # "you@gmial.con" -> "you@gmail.com" -- which clicking accepts.
      #
      # It renders no label -- wrap it in a UI::Forms::Group block to get one.
      class Component < ApplicationComponent
        def initialize(form_builder:, attribute: :email, required: false, html_options: {})
          @form_builder = form_builder
          @attribute = attribute
          @required = required
          @html_options = {data: {"ui--forms--email-target": "input"}}.deep_merge(html_options)
        end
      end
    end
  end
end
