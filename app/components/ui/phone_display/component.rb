# frozen_string_literal: true

module UI
  module PhoneDisplay
    class Component < ApplicationComponent
      def initialize(phone: nil, skip_link: false, **html_options)
        @phone = Phonifyer.display(phone)
        @skip_link = skip_link
        @html_options = html_options
      end

      def render?
        @phone.present?
      end

      def call
        return content_tag(:span, @phone, **@html_options) if @skip_link

        # `;` makes the dialer pause before sending the extension
        link_to(@phone, "tel:#{@phone.tr("x", ";")}", @html_options)
      end
    end
  end
end
