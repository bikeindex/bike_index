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
          # UI::Forms::Input has no email kind, so the type comes from here
          @html_options = {type: "email", data: {"ui--forms--email-target": "input"}}.deep_merge(html_options)
        end

        private

        # The one definition of a domain no message reaches, spent client side too.
        # JS has no \A or \z, where ^ and $ mean the same thing without /m.
        def reserved_pattern
          EmailDomain::RESERVED_REGEX.source.gsub(/\s/, "").gsub("\\A", "^").gsub("\\z", "$")
        end

        # Only the address is the button. It renders empty -- the controller fills it in,
        # the address not being known until the field is checked.
        def did_you_mean_markup
          translation(".did_you_mean_html", email: render(UI::Button::Component.new(color: :link,
            data: {"ui--forms--email-target": "correction", action: "ui--forms--email#accept"})))
        end
      end
    end
  end
end
