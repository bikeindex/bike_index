# frozen_string_literal: true

module UI
  module PhoneDisplay
    class Component < ApplicationComponent
      LINK_CLASS = "twlink tw:font-mono"
      TEXT_CLASS = "tw:font-mono"

      def initialize(phone: nil, skip_link: false, html_class: nil, **html_options)
        @phone = Phonifyer.display(phone)
        @skip_link = skip_link
        @html_class = html_class
        @html_options = html_options
      end

      def render?
        @phone.present?
      end

      def call
        return content_tag(:span, @phone, class: @html_class || TEXT_CLASS, **@html_options) if @skip_link

        # `;` makes the dialer pause before sending the extension
        link_to(@phone, "tel:#{@phone.tr("x", ";")}", class: @html_class || LINK_CLASS, **@html_options)
      end
    end
  end
end
